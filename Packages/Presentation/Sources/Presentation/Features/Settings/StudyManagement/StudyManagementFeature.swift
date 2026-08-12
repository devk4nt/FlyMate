import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public var studies: LoadingState<[Study]> = .idle
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?
        public var selectedStudyID: UUID?

        public init() {}
    }

    public enum Action {
        case onAppear
        case refresh
        case retryTapped
        case studiesResponse(Result<[Study], AppError>)
        case leaveStudyTapped(UUID)
        case confirmAlert(PresentationAction<ConfirmAlert>)
        case leaveCompleted
        case leaveFailed(AppError)

        public enum ConfirmAlert: Equatable {
            case confirmLeave
        }
    }

    @Dependency(\.studyClient) private var studyClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // 첫 진입만 스켈레톤 — 재진입 시 기존 목록을 유지한 채 조용히 갱신
                if case .idle = state.studies {
                    state.studies = .loading
                }
                return fetchStudies()

            // 기존 콘텐츠를 유지한 채 조용히 재조회 (pull-to-refresh, 탈퇴 후)
            case .refresh:
                return fetchStudies()

            case .retryTapped:
                state.studies = .loading
                return fetchStudies()

            case .studiesResponse(.success(let studies)):
                state.studies = .loaded(studies)
                return .none

            case .studiesResponse(.failure(let error)):
                state.studies = .failed(error)
                return .none

            case .leaveStudyTapped(let studyID):
                state.selectedStudyID = studyID
                state.confirmAlert = AlertState {
                    TextState("스터디 탈퇴")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmLeave) {
                        TextState("탈퇴")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("탈퇴하면 이 스터디에 올린 영상과 작성한 피드백·댓글이 모두 삭제됩니다. 정말 탈퇴하시겠습니까?")
                }
                return .none

            case .confirmAlert(.presented(.confirmLeave)):
                guard let studyID = state.selectedStudyID else { return .none }
                let client = studyClient
                return .run { send in
                    do {
                        try await client.leaveStudy(studyID)
                        await send(.leaveCompleted)
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.leaveFailed(appError))
                    }
                }

            case .leaveCompleted:
                state.selectedStudyID = nil
                return .send(.refresh)

            case .leaveFailed:
                state.selectedStudyID = nil
                return .none

            case .confirmAlert:
                return .none
            }
        }
        .ifLet(\.$confirmAlert, action: \.confirmAlert)
    }

    private func fetchStudies() -> Effect<Action> {
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
    }
}
