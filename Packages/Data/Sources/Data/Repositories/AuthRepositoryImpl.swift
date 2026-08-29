import Foundation
import Domain
import Supabase
import Auth

public struct AuthRepositoryImpl: AuthRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func currentUser() async throws -> Domain.User? {
        // 로컬 세션 유무로만 로그인 여부 판단 — `auth.session`은 만료 시 네트워크 리프레시를 타서
        // 오프라인이면 throw하고, 그걸 nil로 삼키면 세션이 살아 있는 유저가 로그인 화면으로 떨어진다.
        // 리프레시는 아래 PostgREST 호출이 필요 시 수행하고, 서버가 세션 무효를 알리면 SDK가 .signedOut을 emit한다.
        guard let session = client.auth.currentSession else {
            return nil
        }
        do {
            return try await fetchUser(id: session.user.id)
        } catch {
            // 세션은 있는데 프로필 조회만 실패(오프라인 등) → 마지막 프로필로 진입, 각 화면이 재시도한다.
            // 단, 서버가 세션 무효(refresh_token_not_found 등)를 알려 SDK가 세션을 지웠다면 로그아웃 처리
            if client.auth.currentSession != nil,
               let cached = Self.cachedUser(), cached.id == session.user.id {
                return cached
            }
            throw error
        }
    }

    /// users 행 조회 + 오프라인 진입용 캐시 갱신
    private func fetchUser(id: UUID) async throws -> Domain.User {
        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        let user = DTOMapper.toDomain(dto)
        Self.cacheUser(user)
        return user
    }

    // MARK: - Last Known User Cache

    private static let cachedUserKey = "auth.lastKnownUser"

    private static func cachedUser() -> Domain.User? {
        UserDefaults.standard.data(forKey: cachedUserKey)
            .flatMap { try? JSONDecoder().decode(Domain.User.self, from: $0) }
    }

    private static func cacheUser(_ user: Domain.User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: cachedUserKey)
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Domain.User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        return try await fetchUser(id: session.user.id)
    }

    public func signInWithEmail(email: String, password: String) async throws -> Domain.User {
        let session = try await client.auth.signIn(email: email, password: password)
        return try await fetchUser(id: session.user.id)
    }

    public func signInWithKakao(accessToken: String) async throws -> Domain.User {
        // 카카오는 Supabase 기본 OIDC에 없으므로 Edge Function으로 토큰 교환
        struct KakaoSignInRequest: Encodable {
            let accessToken: String
            enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
        }
        struct KakaoSignInResponse: Decodable {
            let accessToken: String
            let refreshToken: String
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }

        let response: KakaoSignInResponse = try await client.functions
            .invoke(
                "kakao-sign-in",
                options: .init(body: KakaoSignInRequest(accessToken: accessToken))
            )

        let session = try await client.auth.setSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
        return try await fetchUser(id: session.user.id)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    public func deleteAccount(appleAuthorizationCode: String?) async throws {
        // 서버측 Edge Function 호출로 계정 삭제 처리
        // Apple 계정은 authorization code를 전달해 Sign in with Apple 토큰 revoke
        struct DeleteAccountRequest: Encodable {
            let appleAuthorizationCode: String?
            enum CodingKeys: String, CodingKey {
                case appleAuthorizationCode = "apple_authorization_code"
            }
        }
        try await client.functions.invoke(
            "delete-account",
            options: .init(body: DeleteAccountRequest(appleAuthorizationCode: appleAuthorizationCode))
        )
    }

    public func observeAuthState() -> AsyncStream<Domain.User?> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    // .tokenRefreshed: 오프라인으로 로그인 화면에 머물던 유저가 재연결 시 자동 복구되는 유일한 신호
                    case .signedIn, .tokenRefreshed:
                        // 조회 실패 시 nil을 yield하면 로그인 성공이 로그아웃(FCM 토큰 삭제까지)으로 뒤집힌다 — 성공 시에만 전달
                        if let userID = session?.user.id,
                           let user = try? await fetchUser(id: userID) {
                            continuation.yield(user)
                        }
                    case .signedOut:
                        UserDefaults.standard.removeObject(forKey: Self.cachedUserKey)
                        continuation.yield(nil)
                    default:
                        break
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
