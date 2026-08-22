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
        public var currentUserID: UUID?

        public init(currentUserID: UUID? = nil) {
            self.currentUserID = currentUserID
        }
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

                var study: Study?
                if case .loaded(let studies) = state.studies {
                    study = studies.first { $0.id == studyID }
                }
                let isOwner = state.currentUserID != nil && study?.ownerID == state.currentUserID

                // 팀장 탈퇴는 서버 트리거가 판정하므로(혼자면 스터디 삭제, 멤버 있으면 거부)
                // 클라이언트는 요청 전에 결과를 미리 안내한다
                if isOwner, let study, study.memberCount > 1 {
                    state.selectedStudyID = nil
                    state.confirmAlert = AlertState {
                        TextState("팀장 위임 필요")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("확인")
                        }
                    } message: {
                        TextState("팀장은 다른 멤버에게 팀장을 위임한 후 탈퇴할 수 있습니다. 스터디의 멤버 관리에서 팀장을 위임해주세요.")
                    }
                } else if isOwner {
                    state.confirmAlert = AlertState {
                        TextState("스터디 삭제")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmLeave) {
                            TextState("삭제")
                        }
                        ButtonState(role: .cancel) {
                            TextState("취소")
                        }
                    } message: {
                        TextState("팀장이 탈퇴하면 스터디가 삭제됩니다. 올라온 영상과 피드백·댓글이 모두 사라지며 되돌릴 수 없습니다. 정말 삭제하시겠습니까?")
                    }
                } else {
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

            case .leaveFailed(let error):
                state.selectedStudyID = nil
                state.confirmAlert = AlertState {
                    TextState("스터디 탈퇴 실패")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState(error.localizedDescription)
                }
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
