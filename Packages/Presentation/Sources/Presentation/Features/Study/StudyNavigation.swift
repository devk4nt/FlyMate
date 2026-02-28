import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct StudyNavigationFeature {
    @ObservableState
    public struct State: Equatable {
        public var studyList = StudyListFeature.State()
        public var path = StackState<Path.State>()
        public var currentUserID: UUID?

        public init(currentUserID: UUID? = nil) {
            self.currentUserID = currentUserID
        }
    }

    public enum Action {
        case studyList(StudyListFeature.Action)
        case path(StackActionOf<Path>)
        case navigateToVideo(Study, Video, feedbackID: UUID? = nil)
        case showInviteCode(String)
    }

    @Reducer(state: .equatable)
    public enum Path {
        case studyDetail(StudyDetailFeature)
        case videoDetail(VideoDetailFeature)
        case videoUpload(VideoUploadFeature)
        case memberManagement(MemberManagementFeature)
        case joinRequestManagement(JoinRequestManagementFeature)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.studyList, action: \.studyList) {
            StudyListFeature()
        }
        Reduce { state, action in
            switch action {
            case .showInviteCode(let code):
                state.path.removeAll()
                return .send(.studyList(.showJoinStudy(inviteCode: code)))

            case .studyList(.studyTapped(let study)):
                state.path.append(.studyDetail(StudyDetailFeature.State(study: study, currentUserID: state.currentUserID)))
                return .none

            case .path(.element(_, action: .studyDetail(.videoTapped(let video)))):
                state.path.append(.videoDetail(VideoDetailFeature.State(video: video, currentUserID: state.currentUserID)))
                return .none

            case .path(.element(_, action: .studyDetail(.uploadVideoTapped(let studyID)))):
                state.path.append(.videoUpload(VideoUploadFeature.State(studyID: studyID)))
                return .none

            case .path(.element(let id, action: .studyDetail(.memberManagementTapped))):
                guard case .studyDetail(let detailState) = state.path[id: id] else { return .none }
                state.path.append(
                    .memberManagement(
                        MemberManagementFeature.State(
                            study: detailState.study,
                            currentUserID: state.currentUserID
                        )
                    )
                )
                return .none

            case .path(.element(let id, action: .studyDetail(.joinRequestManagementTapped))):
                guard case .studyDetail(let detailState) = state.path[id: id] else { return .none }
                state.path.append(
                    .joinRequestManagement(
                        JoinRequestManagementFeature.State(studyID: detailState.study.id)
                    )
                )
                return .none

            case .path(.element(_, action: .joinRequestManagement(.delegate(.memberApproved)))):
                // Refresh StudyDetail's study data and pending count
                if let detailID = state.path.ids.first(where: { id in
                    if case .studyDetail = state.path[id: id] { return true }
                    return false
                }) {
                    return .send(.path(.element(id: detailID, action: .studyDetail(.refresh))))
                }
                return .none

            case .path(.element(_, action: .memberManagement(.memberRemoved(let removedUserID)))):
                // Sync removed member back to StudyDetail
                if let detailID = state.path.ids.first(where: { id in
                    if case .studyDetail = state.path[id: id] { return true }
                    return false
                }), case .studyDetail(var detailState) = state.path[id: detailID] {
                    detailState.study.members.removeAll { $0.userID == removedUserID }
                    state.path[id: detailID] = .studyDetail(detailState)
                }
                return .none

            case .path(.element(_, action: .videoUpload(.uploadCompleted))):
                _ = state.path.popLast()
                if let lastID = state.path.ids.last,
                   case .studyDetail = state.path[id: lastID] {
                    return .send(.path(.element(id: lastID, action: .studyDetail(.refresh))))
                }
                return .none

            case .navigateToVideo(let study, let video, let feedbackID):
                state.path.removeAll()
                state.path.append(.studyDetail(StudyDetailFeature.State(study: study, currentUserID: state.currentUserID)))
                state.path.append(.videoDetail(VideoDetailFeature.State(video: video, focusedFeedbackID: feedbackID, currentUserID: state.currentUserID)))
                return .none

            case .studyList, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
