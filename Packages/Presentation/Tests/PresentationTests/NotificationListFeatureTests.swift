import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct NotificationListFeatureTests {

    // MARK: - 로드

    @Test
    func onAppear_로드_성공() async {
        let notifications: [AppNotification] = [
            .notificationMock(id: .notificationID1),
            .notificationMock(id: .notificationID2, isRead: true, createdAt: Date(timeIntervalSince1970: 1_700_000_100))
        ]

        let store = TestStore(
            initialState: NotificationListFeature.State(userID: .userMock)
        ) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.fetchNotifications = { _, _ in notifications }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.notificationsResponse.success) {
            $0.notifications.items = notifications
            $0.notifications.cursor = Date(timeIntervalSince1970: 1_700_000_100)
            $0.notifications.hasMore = false // 2개 < defaultPageSize(20)
            $0.loadingState = .loaded(notifications)
        }

        #expect(store.state.hasUnread == true)
    }

    @Test
    func onAppear_idle이_아니면_무시() async {
        var state = NotificationListFeature.State(userID: .userMock)
        state.loadingState = .loaded([])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        }

        // loadingState가 idle이 아니므로 상태 변경 없이 무시
        await store.send(.onAppear)
    }

    @Test
    func onAppear_로드_실패() async {
        let error = AppError.network(.noConnection)

        let store = TestStore(
            initialState: NotificationListFeature.State(userID: .userMock)
        ) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.fetchNotifications = { _, _ in throw error }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }

        await store.receive(\.notificationsResponse.failure) {
            $0.loadingState = .failed(error)
        }
    }

    @Test
    func refresh시_상태_초기화_후_재조회() async {
        let refreshed: [AppNotification] = [.notificationMock(id: .notificationID1)]

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [.notificationMock(id: .notificationID2, isRead: true)]
        state.notifications.cursor = Date(timeIntervalSince1970: 1_700_000_000)
        state.loadingState = .loaded(state.notifications.items)

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.fetchNotifications = { _, _ in refreshed }
        }

        await store.send(.refresh) {
            $0.loadingState = .loading
            $0.notifications = PaginatedState<AppNotification>()
        }

        await store.receive(\.notificationsResponse.success) {
            $0.notifications.items = refreshed
            $0.notifications.cursor = Date(timeIntervalSince1970: 1_700_000_000)
            $0.notifications.hasMore = false
            $0.loadingState = .loaded(refreshed)
        }
    }

    // MARK: - 페이지네이션

    @Test
    func loadMore_성공시_다음_페이지_추가() async {
        let firstPage: [AppNotification] = [.notificationMock(id: .notificationID1)]
        let nextPage: [AppNotification] = [
            .notificationMock(id: .notificationID2, createdAt: Date(timeIntervalSince1970: 1_699_999_000))
        ]

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = firstPage
        state.notifications.cursor = Date(timeIntervalSince1970: 1_700_000_000)
        state.notifications.hasMore = true
        state.loadingState = .loaded(firstPage)

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.fetchNotifications = { _, cursor in
                // cursor 기반 페이지네이션 확인
                #expect(cursor == Date(timeIntervalSince1970: 1_700_000_000))
                return nextPage
            }
        }

        await store.send(.loadMore) {
            $0.notifications.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.success) {
            $0.notifications.isLoadingMore = false
            $0.notifications.items = firstPage + nextPage
            $0.notifications.cursor = Date(timeIntervalSince1970: 1_699_999_000)
            $0.notifications.hasMore = false
            $0.loadingState = .loaded(firstPage + nextPage)
        }
    }

    @Test
    func hasMore_false면_loadMore_무시() async {
        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [.notificationMock(id: .notificationID1)]
        state.notifications.hasMore = false
        state.loadingState = .loaded(state.notifications.items)

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        }

        await store.send(.loadMore)
    }

    @Test
    func 로딩중이면_loadMore_무시() async {
        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [.notificationMock(id: .notificationID1)]
        state.notifications.isLoadingMore = true
        state.loadingState = .loaded(state.notifications.items)

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        }

        await store.send(.loadMore)
    }

    // MARK: - 개별 읽음 처리

    @Test
    func 미읽음_알림_탭시_옵티미스틱_읽음처리_및_네비게이션_delegate() async {
        let notification = AppNotification.notificationMock(
            id: .notificationID1,
            videoID: .videoMock,
            feedbackID: .feedbackMock
        )

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [notification]
        state.loadingState = .loaded([notification])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.markAsRead = { _ in }
        }

        await store.send(.notificationTapped(notification)) {
            $0.notifications.items[0].isRead = true
            $0.loadingState = .loaded($0.notifications.items)
        }

        await store.receive(\.delegate.navigateToVideo)
        await store.receive(\.markAsReadResponse)
    }

    @Test
    func 읽음처리_실패시_롤백() async {
        // referenceVideoID가 없는 알림 — 네비게이션 없이 읽음 처리만
        let notification = AppNotification.notificationMock(id: .notificationID1, videoID: nil)

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [notification]
        state.loadingState = .loaded([notification])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.markAsRead = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.notificationTapped(notification)) {
            $0.notifications.items[0].isRead = true
            $0.loadingState = .loaded($0.notifications.items)
        }

        await store.receive(\.markAsReadResponse) {
            $0.notifications.items[0].isRead = false
            $0.loadingState = .loaded($0.notifications.items)
        }
    }

    @Test
    func 읽은_알림_탭시_네비게이션만() async {
        let notification = AppNotification.notificationMock(
            id: .notificationID1,
            isRead: true,
            videoID: .videoMock
        )

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [notification]
        state.loadingState = .loaded([notification])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        }

        await store.send(.notificationTapped(notification))
        await store.receive(\.delegate.navigateToVideo)
    }

    @Test
    func 읽은_알림_videoID_없으면_무시() async {
        let notification = AppNotification.notificationMock(
            id: .notificationID1,
            isRead: true,
            videoID: nil
        )

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [notification]
        state.loadingState = .loaded([notification])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        }

        await store.send(.notificationTapped(notification))
    }

    // MARK: - 전체 읽음 처리

    @Test
    func 전체_읽음_처리_옵티미스틱_업데이트() async {
        let notifications: [AppNotification] = [
            .notificationMock(id: .notificationID1),
            .notificationMock(id: .notificationID2)
        ]

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = notifications
        state.loadingState = .loaded(notifications)

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.markAllAsRead = { _ in }
        }

        await store.send(.markAllAsReadTapped) {
            $0.notifications.items[0].isRead = true
            $0.notifications.items[1].isRead = true
            $0.loadingState = .loaded($0.notifications.items)
        }

        // Result<Void, _> 케이스패스(\.markAllAsReadResponse.success)는 Swift 6.4 beta 맹글러 크래시 유발 — 상위 케이스로 수신
        await store.receive(\.markAllAsReadResponse)

        #expect(store.state.hasUnread == false)
    }

    @Test
    func 전체_읽음_실패시_재조회로_롤백() async {
        let notification = AppNotification.notificationMock(id: .notificationID1)

        var state = NotificationListFeature.State(userID: .userMock)
        state.notifications.items = [notification]
        state.loadingState = .loaded([notification])

        let store = TestStore(initialState: state) {
            NotificationListFeature()
        } withDependencies: {
            $0.notificationClient.markAllAsRead = { _ in
                throw AppError.network(.timeout)
            }
            // 롤백용 재조회는 서버 원본(미읽음) 반환
            $0.notificationClient.fetchNotifications = { _, _ in [notification] }
        }

        await store.send(.markAllAsReadTapped) {
            $0.notifications.items[0].isRead = true
            $0.loadingState = .loaded($0.notifications.items)
        }

        await store.receive(\.markAllAsReadResponse)

        await store.receive(\.notificationsResponse.success) {
            $0.notifications.items = [notification]
            $0.notifications.cursor = notification.createdAt
            $0.notifications.hasMore = false
            $0.loadingState = .loaded([notification])
        }
    }
}

// MARK: - Mock Data

private extension UUID {
    static let userMock = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let videoMock = UUID(uuidString: "00000000-0000-0000-0000-000000000300")!
    static let feedbackMock = UUID(uuidString: "00000000-0000-0000-0000-000000000400")!
    static let notificationID1 = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
    static let notificationID2 = UUID(uuidString: "00000000-0000-0000-0000-000000000602")!
}

private extension AppNotification {
    static func notificationMock(
        id: UUID,
        isRead: Bool = false,
        videoID: UUID? = .videoMock,
        feedbackID: UUID? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> AppNotification {
        AppNotification(
            id: id,
            recipientID: .userMock,
            type: .feedbackOnMyVideo,
            title: "새 피드백",
            body: "회원님의 영상에 새 피드백이 달렸습니다.",
            referenceVideoID: videoID,
            referenceFeedbackID: feedbackID,
            isRead: isRead,
            createdAt: createdAt
        )
    }
}
