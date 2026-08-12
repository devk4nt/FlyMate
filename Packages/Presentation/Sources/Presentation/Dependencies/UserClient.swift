import Foundation
import ComposableArchitecture
import Domain

public struct UserClient: Sendable {
    public var fetchUser: @Sendable (UUID) async throws -> User
    public var updateProfile: @Sendable (UpdateProfileRequest) async throws -> User
    public var registerDeviceToken: @Sendable (String) async throws -> Void
    public var removeDeviceToken: @Sendable (String) async throws -> Void
    public var updateNotificationSettings: @Sendable (Bool) async throws -> Void
    public var fetchMyActivityStats: @Sendable () async throws -> MyActivityStats

    public init(
        fetchUser: @escaping @Sendable (UUID) async throws -> User,
        updateProfile: @escaping @Sendable (UpdateProfileRequest) async throws -> User,
        registerDeviceToken: @escaping @Sendable (String) async throws -> Void,
        removeDeviceToken: @escaping @Sendable (String) async throws -> Void,
        updateNotificationSettings: @escaping @Sendable (Bool) async throws -> Void,
        fetchMyActivityStats: @escaping @Sendable () async throws -> MyActivityStats
    ) {
        self.fetchUser = fetchUser
        self.updateProfile = updateProfile
        self.registerDeviceToken = registerDeviceToken
        self.removeDeviceToken = removeDeviceToken
        self.updateNotificationSettings = updateNotificationSettings
        self.fetchMyActivityStats = fetchMyActivityStats
    }
}

extension UserClient: TestDependencyKey {
    public static let testValue = UserClient(
        fetchUser: unimplemented("\(Self.self).fetchUser"),
        updateProfile: unimplemented("\(Self.self).updateProfile"),
        registerDeviceToken: unimplemented("\(Self.self).registerDeviceToken"),
        removeDeviceToken: unimplemented("\(Self.self).removeDeviceToken"),
        updateNotificationSettings: unimplemented("\(Self.self).updateNotificationSettings"),
        fetchMyActivityStats: unimplemented("\(Self.self).fetchMyActivityStats")
    )
}

extension DependencyValues {
    public var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
