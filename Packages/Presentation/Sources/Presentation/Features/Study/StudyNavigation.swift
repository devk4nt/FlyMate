import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct StudyNavigationFeature {
    @ObservableState
    public struct State: Equatable {
        public var studyList = StudyListFeature.State()
        public var path = StackState<Path.State>()
        public var pendingInviteCode: String?

        public init() {}
    }

    public enum Action {
        case studyList(StudyListFeature.Action)
        case path(StackActionOf<Path>)
        case navigateToVideo(Study, Video)
    }

    @Reducer(state: .equatable)
    public enum Path {
        case studyDetail(StudyDetailFeature)
        case videoDetail(VideoDetailFeature)
        case videoUpload(VideoUploadFeature)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.studyList, action: \.studyList) {
            StudyListFeature()
        }
        Reduce { state, action in
            switch action {
            case .studyList(.studyTapped(let study)):
                state.path.append(.studyDetail(StudyDetailFeature.State(study: study)))
                return .none

            case .path(.element(_, action: .studyDetail(.videoTapped(let video)))):
                state.path.append(.videoDetail(VideoDetailFeature.State(video: video)))
                return .none

            case .path(.element(_, action: .studyDetail(.uploadVideoTapped(let studyID)))):
                state.path.append(.videoUpload(VideoUploadFeature.State(studyID: studyID)))
                return .none

            case .path(.element(_, action: .videoUpload(.uploadCompleted))):
                _ = state.path.popLast()
                if let lastID = state.path.ids.last,
                   case .studyDetail = state.path[id: lastID] {
                    return .send(.path(.element(id: lastID, action: .studyDetail(.refresh))))
                }
                return .none

            case .navigateToVideo(let study, let video):
                state.path.removeAll()
                state.path.append(.studyDetail(StudyDetailFeature.State(study: study)))
                state.path.append(.videoDetail(VideoDetailFeature.State(video: video)))
                return .none

            case .studyList, .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
