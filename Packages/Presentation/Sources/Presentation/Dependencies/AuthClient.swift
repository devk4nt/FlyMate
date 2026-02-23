import Foundation
import ComposableArchitecture
import Domain

public struct AuthClient: Sendable {
    public var currentUser: @Sendable () async throws -> User?
    public var signInWithApple: @Sendable (String, String) async throws -> User
    public var signInWithKakao: @Sendable (String) async throws -> User
    public var signOut: @Sendable () async throws -> Void
    public var deleteAccount: @Sendable () async throws -> Void
    public var observeAuthState: @Sendable () -> AsyncStream<User?>
    /// 디버그 자동 로그인 (skipAuth 모드에서 Supabase 세션 확보용)
    public var debugSignIn: (@Sendable () async throws -> Void)?

    public init(
        currentUser: @escaping @Sendable () async throws -> User?,
        signInWithApple: @escaping @Sendable (String, String) async throws -> User,
        signInWithKakao: @escaping @Sendable (String) async throws -> User,
        signOut: @escaping @Sendable () async throws -> Void,
        deleteAccount: @escaping @Sendable () async throws -> Void,
        observeAuthState: @escaping @Sendable () -> AsyncStream<User?>,
        debugSignIn: (@Sendable () async throws -> Void)? = nil
    ) {
        self.currentUser = currentUser
        self.signInWithApple = signInWithApple
        self.signInWithKakao = signInWithKakao
        self.signOut = signOut
        self.deleteAccount = deleteAccount
        self.observeAuthState = observeAuthState
        self.debugSignIn = debugSignIn
    }
}

extension AuthClient: TestDependencyKey {
    public static let testValue = AuthClient(
        currentUser: unimplemented("\(Self.self).currentUser"),
        signInWithApple: unimplemented("\(Self.self).signInWithApple"),
        signInWithKakao: unimplemented("\(Self.self).signInWithKakao"),
        signOut: unimplemented("\(Self.self).signOut"),
        deleteAccount: unimplemented("\(Self.self).deleteAccount"),
        observeAuthState: unimplemented("\(Self.self).observeAuthState", placeholder: .finished)
    )
}

extension DependencyValues {
    public var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
