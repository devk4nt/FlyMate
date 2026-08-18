import Foundation
import ComposableArchitecture
import Domain

public struct NotificationClient: Sendable {
    public var fetchNotifications: @Sendable (UUID, Date?) async throws -> [AppNotification]
    public var fetchUnreadCount: @Sendable (UUID) async throws -> Int
    public var fetchStartupAnnouncement: @Sendable () async throws -> AppNotification?
    public var markAsRead: @Sendable (UUID) async throws -> Void
    public var markAllAsRead: @Sendable (UUID) async throws -> Void
    public var observeNotifications: @Sendable (UUID) -> AsyncStream<AppNotification>

    public init(
        fetchNotifications: @escaping @Sendable (UUID, Date?) async throws -> [AppNotification],
        fetchUnreadCount: @escaping @Sendable (UUID) async throws -> Int,
        fetchStartupAnnouncement: @escaping @Sendable () async throws -> AppNotification?,
        markAsRead: @escaping @Sendable (UUID) async throws -> Void,
        markAllAsRead: @escaping @Sendable (UUID) async throws -> Void,
        observeNotifications: @escaping @Sendable (UUID) -> AsyncStream<AppNotification>
    ) {
        self.fetchNotifications = fetchNotifications
        self.fetchUnreadCount = fetchUnreadCount
        self.fetchStartupAnnouncement = fetchStartupAnnouncement
        self.markAsRead = markAsRead
        self.markAllAsRead = markAllAsRead
        self.observeNotifications = observeNotifications
    }
}

extension NotificationClient: TestDependencyKey {
    public static let testValue = NotificationClient(
        fetchNotifications: unimplemented("\(Self.self).fetchNotifications"),
        fetchUnreadCount: unimplemented("\(Self.self).fetchUnreadCount", placeholder: 0),
        fetchStartupAnnouncement: unimplemented("\(Self.self).fetchStartupAnnouncement", placeholder: nil),
        markAsRead: unimplemented("\(Self.self).markAsRead"),
        markAllAsRead: unimplemented("\(Self.self).markAllAsRead"),
        observeNotifications: unimplemented("\(Self.self).observeNotifications", placeholder: .finished)
    )
}

extension DependencyValues {
    public var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
