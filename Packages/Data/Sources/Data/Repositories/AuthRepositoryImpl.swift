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
        guard let session = try? await client.auth.session else {
            return nil
        }
        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Domain.User {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
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
        let dto: UserDTO = try await client.from(SupabaseConfig.Table.users)
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value
        return DTOMapper.toDomain(dto)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    public func deleteAccount() async throws {
        // 서버측 Edge Function 호출로 계정 삭제 처리
        try await client.functions.invoke("delete-account")
    }

    public func observeAuthState() -> AsyncStream<Domain.User?> {
        AsyncStream { continuation in
            let task = Task {
                for await (event, session) in client.auth.authStateChanges {
                    switch event {
                    case .signedIn:
                        if let userID = session?.user.id {
                            let dto: UserDTO? = try? await client.from(SupabaseConfig.Table.users)
                                .select()
                                .eq("id", value: userID)
                                .single()
                                .execute()
                                .value
                            continuation.yield(dto.map(DTOMapper.toDomain))
                        }
                    case .signedOut:
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
