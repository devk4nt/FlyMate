import Foundation

public protocol NotificationRepository: Sendable {
    /// 알림 목록을 조회한다 (커서 기반 페이지네이션).
    func fetchNotifications(userID: UUID, cursor: Date?) async throws -> [AppNotification]

    /// 읽지 않은 알림 개수를 조회한다.
    func fetchUnreadCount(userID: UUID) async throws -> Int

    /// 특정 알림을 읽음 처리한다.
    func markAsRead(id: UUID) async throws

    /// 모든 알림을 읽음 처리한다.
    func markAllAsRead(userID: UUID) async throws

    /// 새 알림을 실시간 구독한다.
    func observeNotifications(userID: UUID) -> AsyncStream<AppNotification>
}
