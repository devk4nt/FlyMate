import Foundation

public struct UpdateProfileRequest: Equatable, Sendable {
    public let name: String
    public let profileImageData: Data?

    public init(name: String, profileImageData: Data? = nil) {
        self.name = name
        self.profileImageData = profileImageData
    }
}

public protocol UserRepository: Sendable {
    /// 사용자 프로필을 조회한다.
    func fetchUser(id: UUID) async throws -> User

    /// 프로필을 업데이트한다.
    func updateProfile(_ request: UpdateProfileRequest) async throws -> User

    /// FCM 디바이스 토큰을 등록한다.
    func registerDeviceToken(_ token: String) async throws

    /// FCM 디바이스 토큰을 삭제한다 (로그아웃 시).
    func removeDeviceToken(_ token: String) async throws

    /// 알림 설정을 업데이트한다.
    func updateNotificationSettings(enabled: Bool) async throws
}
