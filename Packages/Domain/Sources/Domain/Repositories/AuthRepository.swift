import Foundation

public protocol AuthRepository: Sendable {
    /// 현재 인증된 사용자 세션을 확인한다.
    func currentUser() async throws -> User?

    /// Apple 로그인을 수행한다.
    func signInWithApple(idToken: String, nonce: String) async throws -> User

    /// 카카오 로그인을 수행한다.
    func signInWithKakao(accessToken: String) async throws -> User

    /// 이메일 로그인을 수행한다. App Store 심사용 데모 계정 전용 (일반 UI에는 노출되지 않음).
    func signInWithEmail(email: String, password: String) async throws -> User

    /// 로그아웃을 수행한다.
    func signOut() async throws

    /// 계정을 탈퇴한다. Apple 계정은 재인증으로 받은 authorization code를 전달해
    /// 서버에서 Sign in with Apple 토큰을 revoke한다 (App Store 심사 요구사항).
    func deleteAccount(appleAuthorizationCode: String?) async throws

    /// 인증 상태 변경을 관찰한다.
    func observeAuthState() -> AsyncStream<User?>
}
