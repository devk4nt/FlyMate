import Foundation
import ComposableArchitecture
import UserNotifications

public struct PushNotificationClient: Sendable {
    public var requestAuthorization: @Sendable () async throws -> Bool
    public var getAuthorizationStatus: @Sendable () async -> UNAuthorizationStatus
    public var registerForRemoteNotifications: @Sendable () async -> Void
    public var observeFCMToken: @Sendable () -> AsyncStream<String>
    public var observePushNotificationTapped: @Sendable () -> AsyncStream<[String: String]>

    public init(
        requestAuthorization: @escaping @Sendable () async throws -> Bool,
        getAuthorizationStatus: @escaping @Sendable () async -> UNAuthorizationStatus,
        registerForRemoteNotifications: @escaping @Sendable () async -> Void,
        observeFCMToken: @escaping @Sendable () -> AsyncStream<String>,
        observePushNotificationTapped: @escaping @Sendable () -> AsyncStream<[String: String]>
    ) {
        self.requestAuthorization = requestAuthorization
        self.getAuthorizationStatus = getAuthorizationStatus
        self.registerForRemoteNotifications = registerForRemoteNotifications
        self.observeFCMToken = observeFCMToken
        self.observePushNotificationTapped = observePushNotificationTapped
    }
}

extension PushNotificationClient: TestDependencyKey {
    public static let testValue = PushNotificationClient(
        requestAuthorization: unimplemented("\(Self.self).requestAuthorization"),
        getAuthorizationStatus: unimplemented("\(Self.self).getAuthorizationStatus"),
        registerForRemoteNotifications: unimplemented("\(Self.self).registerForRemoteNotifications"),
        observeFCMToken: unimplemented("\(Self.self).observeFCMToken"),
        observePushNotificationTapped: unimplemented("\(Self.self).observePushNotificationTapped")
    )
}

extension DependencyValues {
    public var pushNotificationClient: PushNotificationClient {
        get { self[PushNotificationClient.self] }
        set { self[PushNotificationClient.self] = newValue }
    }
}
