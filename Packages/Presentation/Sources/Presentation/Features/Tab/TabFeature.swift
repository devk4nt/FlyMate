import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct TabFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .study
        public var currentUser: User
        public var study: StudyNavigationFeature.State
        public var feedbackManagement: FeedbackManagementFeature.State
        public var notificationList: NotificationListFeature.State
        public var settings: SettingsFeature.State
        public var unreadNotificationCount: Int = 0
        public var isNotificationSheetPresented = false

        public init(currentUser: User) {
            self.currentUser = currentUser
            self.study = StudyNavigationFeature.State(currentUserID: currentUser.id)
            self.feedbackManagement = FeedbackManagementFeature.State(userID: currentUser.id)
            self.notificationList = NotificationListFeature.State(userID: currentUser.id)
            self.settings = SettingsFeature.State(currentUser: currentUser)
        }

        public enum Tab: Equatable, Hashable {
            case study
            case feedback
            case settings
        }
    }

    public enum Action {
        case onAppear
        case tabSelected(State.Tab)
        case notificationBellTapped
        case dismissNotificationSheet
        case study(StudyNavigationFeature.Action)
        case feedbackManagement(FeedbackManagementFeature.Action)
        case notificationList(NotificationListFeature.Action)
        case settings(SettingsFeature.Action)
        case navigateToVideo(Study, Video)
        case navigationFailed
        case showInviteCode(String)
        case newNotificationReceived(AppNotification)
        case unreadCountResponse(Int)
    }

    private enum CancelID {
        case realtimeNotification
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.videoClient) private var videoClient
    @Dependency(\.notificationClient) private var notificationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.study, action: \.study) {
            StudyNavigationFeature()
        }
        Scope(state: \.feedbackManagement, action: \.feedbackManagement) {
            FeedbackManagementFeature()
        }
        Scope(state: \.notificationList, action: \.notificationList) {
            NotificationListFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let client = notificationClient
                let userID = state.currentUser.id
                return .merge(
                    .run { send in
                        let count = try await client.fetchUnreadCount(userID)
                        await send(.unreadCountResponse(count))
                    },
                    .run { send in
                        for await notification in client.observeNotifications(userID) {
                            await send(.newNotificationReceived(notification))
                        }
                    }
                    .cancellable(id: CancelID.realtimeNotification)
                )

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .notificationBellTapped,
                 .study(.studyList(.notificationBellTapped)):
                state.isNotificationSheetPresented = true
                return .none

            case .dismissNotificationSheet:
                state.isNotificationSheetPresented = false
                return .none

            case .newNotificationReceived(let notification):
                state.unreadNotificationCount += 1
                syncUnreadCount(&state)
                state.notificationList.notifications.items.insert(notification, at: 0)
                if case .loaded = state.notificationList.loadingState {
                    state.notificationList.loadingState = .loaded(state.notificationList.notifications.items)
                }
                return .none

            case .unreadCountResponse(let count):
                state.unreadNotificationCount = count
                syncUnreadCount(&state)
                return .none

            case .notificationList(.delegate(.navigateToVideo(let videoID))):
                state.isNotificationSheetPresented = false
                state.selectedTab = .study
                let studyClient = studyClient
                let videoClient = videoClient
                return .run { send in
                    try await Task.sleep(for: .milliseconds(350))
                    let video = try await videoClient.fetchVideo(videoID)
                    let study = try await studyClient.fetchStudy(video.studyID)
                    await send(.navigateToVideo(study, video))
                } catch: { _, send in
                    await send(.navigationFailed)
                }

            case .notificationList(.markAllAsReadTapped):
                state.unreadNotificationCount = 0
                syncUnreadCount(&state)
                return .none

            case .notificationList(.markAllAsReadResponse(.failure)):
                let client = notificationClient
                let userID = state.currentUser.id
                return .run { send in
                    let count = try await client.fetchUnreadCount(userID)
                    await send(.unreadCountResponse(count))
                }

            case .notificationList(.notificationTapped(let notification)):
                if !notification.isRead, state.unreadNotificationCount > 0 {
                    state.unreadNotificationCount -= 1
                    syncUnreadCount(&state)
                }
                return .none

            case .feedbackManagement(.received(.feedbackTapped(let feedback))),
                 .feedbackManagement(.given(.feedbackTapped(let feedback))):
                state.selectedTab = .study
                let studyClient = studyClient
                let videoClient = videoClient
                return .run { send in
                    let study = try await studyClient.fetchStudy(feedback.studyID)
                    let video = try await videoClient.fetchVideo(feedback.videoID)
                    await send(.navigateToVideo(study, video))
                } catch: { _, send in
                    await send(.navigationFailed)
                }

            case .showInviteCode(let code):
                state.selectedTab = .study
                return .send(.study(.showInviteCode(code)))

            case .navigateToVideo(let study, let video):
                return .send(.study(.navigateToVideo(study, video)))

            case .navigationFailed:
                return .none

            case .study, .feedbackManagement, .notificationList, .settings:
                return .none
            }
        }
    }

    private func syncUnreadCount(_ state: inout State) {
        state.study.studyList.unreadNotificationCount = state.unreadNotificationCount
    }
}
