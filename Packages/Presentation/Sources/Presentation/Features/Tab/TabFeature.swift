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
        public var settings: SettingsFeature.State

        public init(currentUser: User) {
            self.currentUser = currentUser
            self.study = StudyNavigationFeature.State()
            self.feedbackManagement = FeedbackManagementFeature.State(userID: currentUser.id)
            self.settings = SettingsFeature.State(currentUser: currentUser)
        }

        public enum Tab: Equatable, Hashable {
            case study
            case feedback
            case settings
        }
    }

    public enum Action {
        case tabSelected(State.Tab)
        case study(StudyNavigationFeature.Action)
        case feedbackManagement(FeedbackManagementFeature.Action)
        case settings(SettingsFeature.Action)
        case navigateToVideo(Study, Video)
        case navigationFailed
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.videoClient) private var videoClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.study, action: \.study) {
            StudyNavigationFeature()
        }
        Scope(state: \.feedbackManagement, action: \.feedbackManagement) {
            FeedbackManagementFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
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

            case .navigateToVideo(let study, let video):
                return .send(.study(.navigateToVideo(study, video)))

            case .navigationFailed:
                return .none

            case .study, .feedbackManagement, .settings:
                return .none
            }
        }
    }
}
