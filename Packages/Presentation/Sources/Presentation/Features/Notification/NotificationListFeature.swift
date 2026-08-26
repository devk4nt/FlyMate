import ComposableArchitecture
import Core
import Domain
import Foundation

@Reducer
public struct NotificationListFeature {
    @ObservableState
    public struct State: Equatable {
        public let userID: UUID
        public var notifications = PaginatedState<AppNotification>()
        public var loadingState: LoadingState<[AppNotification]> = .idle
        @Presents public var announcement: AnnouncementDetailFeature.State?

        public var hasUnread: Bool {
            notifications.items.contains { !$0.isRead }
        }

        public init(userID: UUID) {
            self.userID = userID
        }
    }

    public enum Action {
        case onAppear
        case refresh
        case notificationsResponse(Result<[AppNotification], AppError>)
        case loadMore
        case loadMoreResponse(Result<[AppNotification], AppError>)
        case notificationTapped(AppNotification)
        case markAllAsReadTapped
        case markAllAsReadResponse(Result<Void, AppError>)
        case markAsReadResponse(id: UUID, Result<Void, AppError>)
        case announcement(PresentationAction<AnnouncementDetailFeature.Action>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case navigateToVideo(videoID: UUID, feedbackID: UUID?)
            case navigateToQuickFeedback
            case navigateToRecruit
        }
    }

    @Dependency(\.notificationClient) private var notificationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.loadingState else { return .none }
                state.loadingState = .loading
                let client = notificationClient
                return fetchNotifications(client: client, userID: state.userID, cursor: nil)

            case .refresh:
                // 로드된 콘텐츠는 유지 — pull-to-refresh 시 스켈레톤 대신 .refreshable 스피너가 로딩 표시
                if state.loadingState.value == nil { state.loadingState = .loading }
                let client = notificationClient
                return fetchNotifications(client: client, userID: state.userID, cursor: nil)

            case .notificationsResponse(.success(let notifications)):
                state.notifications.items = notifications
                state.notifications.cursor = notifications.last?.createdAt
                state.notifications.hasMore = notifications.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(notifications)
                return .none

            case .notificationsResponse(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .loadMore:
                guard !state.notifications.isLoadingMore, state.notifications.hasMore else { return .none }
                state.notifications.isLoadingMore = true
                let client = notificationClient
                return fetchNotifications(
                    client: client,
                    userID: state.userID,
                    cursor: state.notifications.cursor
                )

            case .loadMoreResponse(.success(let newNotifications)):
                state.notifications.isLoadingMore = false
                state.notifications.items.append(contentsOf: newNotifications)
                state.notifications.cursor = newNotifications.last?.createdAt
                state.notifications.hasMore = newNotifications.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(state.notifications.items)
                return .none

            case .loadMoreResponse(.failure):
                state.notifications.isLoadingMore = false
                return .none

            case .notificationTapped(let notification):
                if notification.type == .announcement {
                    state.announcement = AnnouncementDetailFeature.State(notification: notification)
                    guard !notification.isRead else { return .none }
                    if let index = state.notifications.items.firstIndex(where: { $0.id == notification.id }) {
                        state.notifications.items[index].isRead = true
                        state.loadingState = .loaded(state.notifications.items)
                    }
                    let client = notificationClient
                    let notificationID = notification.id
                    return .run { send in
                        do {
                            try await client.markAsRead(notificationID)
                            await send(.markAsReadResponse(id: notificationID, .success(())))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.markAsReadResponse(id: notificationID, .failure(appError)))
                        }
                    }
                }
                // Optimistic update: mark as read immediately
                if !notification.isRead {
                    if let index = state.notifications.items.firstIndex(where: { $0.id == notification.id }) {
                        state.notifications.items[index].isRead = true
                        state.loadingState = .loaded(state.notifications.items)
                    }
                    let client = notificationClient
                    let notificationID = notification.id
                    return .merge(
                        .run { send in
                            do {
                                try await client.markAsRead(notificationID)
                                await send(.markAsReadResponse(id: notificationID, .success(())))
                            } catch {
                                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                                await send(.markAsReadResponse(id: notificationID, .failure(appError)))
                            }
                        },
                        navigationEffect(for: notification)
                    )
                }
                // Already read — just navigate
                return navigationEffect(for: notification)

            case .markAsReadResponse(let id, .failure):
                // Rollback on failure
                if let index = state.notifications.items.firstIndex(where: { $0.id == id }) {
                    state.notifications.items[index].isRead = false
                    state.loadingState = .loaded(state.notifications.items)
                }
                return .none

            case .markAsReadResponse:
                return .none

            case .markAllAsReadTapped:
                // Optimistic update: mark all as read immediately
                for index in state.notifications.items.indices {
                    state.notifications.items[index].isRead = true
                }
                state.loadingState = .loaded(state.notifications.items)
                let client = notificationClient
                let userID = state.userID
                return .run { send in
                    do {
                        try await client.markAllAsRead(userID)
                        await send(.markAllAsReadResponse(.success(())))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.markAllAsReadResponse(.failure(appError)))
                    }
                }

            case .markAllAsReadResponse(.failure):
                // Rollback: re-fetch to get accurate state
                let client = notificationClient
                return fetchNotifications(client: client, userID: state.userID, cursor: nil)

            case .markAllAsReadResponse(.success):
                return .none

            case .delegate:
                return .none

            case .announcement:
                return .none
            }
        }
        .ifLet(\.$announcement, action: \.announcement) {
            AnnouncementDetailFeature()
        }
    }

    private func navigationEffect(for notification: AppNotification) -> Effect<Action> {
        if notification.referenceQuickFeedbackRequestID != nil {
            return .send(.delegate(.navigateToQuickFeedback))
        }
        if notification.type == .recruitPost {
            return .send(.delegate(.navigateToRecruit))
        }
        if let videoID = notification.referenceVideoID {
            return .send(.delegate(.navigateToVideo(
                videoID: videoID,
                feedbackID: notification.referenceFeedbackID
            )))
        }
        return .none
    }

    private func fetchNotifications(
        client: NotificationClient,
        userID: UUID,
        cursor: Date?
    ) -> Effect<Action> {
        .run { send in
            do {
                let notifications = try await client.fetchNotifications(userID, cursor)
                if cursor == nil {
                    await send(.notificationsResponse(.success(notifications)))
                } else {
                    await send(.loadMoreResponse(.success(notifications)))
                }
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                if cursor == nil {
                    await send(.notificationsResponse(.failure(appError)))
                } else {
                    await send(.loadMoreResponse(.failure(appError)))
                }
            }
        }
    }
}
