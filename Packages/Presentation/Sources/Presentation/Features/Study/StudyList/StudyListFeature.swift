import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyListFeature {
    @ObservableState
    public struct State: Equatable {
        public var studies: LoadingState<[Study]> = .idle
        public var unreadNotificationCount: Int = 0
        @Presents public var createStudy: StudyCreateFeature.State?
        @Presents public var joinStudy: JoinStudyFeature.State?

        public init() {}
    }

    public enum Action {
        case onAppear
        case refresh
        case studiesResponse(Result<[Study], AppError>)
        case studyTapped(Study)
        case notificationBellTapped
        case createStudyTapped
        case joinStudyTapped
        case showJoinStudy(inviteCode: String)
        case createStudy(PresentationAction<StudyCreateFeature.Action>)
        case joinStudy(PresentationAction<JoinStudyFeature.Action>)
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.studies else { return .none }
                state.studies = .loading
                let client = studyClient
                return .run { send in
                    do {
                        let studies = try await client.fetchMyStudies()
                        await send(.studiesResponse(.success(studies)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.studiesResponse(.failure(appError)))
                    }
                }

            case .refresh:
                // 로드된 콘텐츠는 유지 — pull-to-refresh 시 스켈레톤 대신 .refreshable 스피너가 로딩 표시
                if state.studies.value == nil { state.studies = .loading }
                let client = studyClient
                return .run { send in
                    do {
                        let studies = try await client.fetchMyStudies()
                        await send(.studiesResponse(.success(studies)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.studiesResponse(.failure(appError)))
                    }
                }

            case .studiesResponse(.success(let studies)):
                state.studies = .loaded(studies)
                return .none

            case .studiesResponse(.failure(let error)):
                state.studies = .failed(error)
                return .none

            case .studyTapped:
                return .none // Handled by parent

            case .notificationBellTapped:
                return .none // Handled by parent (TabFeature)

            case .createStudyTapped:
                state.createStudy = StudyCreateFeature.State()
                return .none

            case .joinStudyTapped:
                state.joinStudy = JoinStudyFeature.State()
                return .none

            case .showJoinStudy(inviteCode: let code):
                state.joinStudy = JoinStudyFeature.State(inviteCode: code)
                return .none

            case .joinStudy(.presented(.delegate(.joinRequested))):
                state.joinStudy = nil
                return .none

            case .createStudy(.presented(.studyCreated)):
                state.createStudy = nil
                return .send(.refresh)

            case .createStudy, .joinStudy:
                return .none
            }
        }
        .ifLet(\.$createStudy, action: \.createStudy) {
            StudyCreateFeature()
        }
        .ifLet(\.$joinStudy, action: \.joinStudy) {
            JoinStudyFeature()
        }
    }
}
