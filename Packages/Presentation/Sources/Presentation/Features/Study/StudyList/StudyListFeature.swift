import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct StudyListFeature {
    @ObservableState
    public struct State: Equatable {
        public var studies: LoadingState<[Study]> = .idle
        public var quickFeedback: LoadingState<QuickFeedbackDashboard> = .idle
        /// 내가 보낸 승인 대기 중인 가입 신청 (신청자 관점 — 조회 실패 시 섹션만 숨김)
        public var myJoinRequests: [JoinRequest] = []
        public var unreadNotificationCount: Int = 0
        @Presents public var createStudy: StudyCreateFeature.State?
        @Presents public var joinStudy: JoinStudyFeature.State?
        @Presents public var cancelConfirmAlert: AlertState<Action.CancelConfirm>?
        @Presents public var practiceMirror: PracticeMirrorFeature.State?
        var requestToCancel: JoinRequest?

        /// 첫 빠른 피드백 요청 전이면 true — 홈 Hero를 첫 업로드 유도 모드로 전환
        // ponytail: 스터디 영상 업로드 여부는 안 본다 — 빠른 피드백 첫 요청 기준으로 충분
        public var awaitingFirstUpload: Bool {
            guard case .loaded(let dashboard) = quickFeedback else { return false }
            return dashboard.myRequests.isEmpty
        }

        public init() {}
    }

    public enum Action {
        case onAppear
        case refresh
        case studiesResponse(Result<[Study], AppError>)
        case quickFeedbackResponse(Result<QuickFeedbackDashboard, AppError>)
        case refreshQuickFeedback
        case quickFeedbackPrimaryTapped
        case quickFeedbackHubTapped
        case studyTapped(Study)
        case notificationBellTapped
        case createStudyTapped
        case joinStudyTapped
        case practiceMirrorTapped
        case practiceMirror(PresentationAction<PracticeMirrorFeature.Action>)
        case showJoinStudy(inviteCode: String)
        case createStudy(PresentationAction<StudyCreateFeature.Action>)
        case joinStudy(PresentationAction<JoinStudyFeature.Action>)
        case myJoinRequestsResponse(Result<[JoinRequest], AppError>)
        case cancelRequestTapped(JoinRequest)
        case cancelConfirmAlert(PresentationAction<CancelConfirm>)
        case cancelRequestFailed

        public enum CancelConfirm: Equatable {
            case confirmCancel
        }
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.studies else { return .none }
                state.studies = .loading
                state.quickFeedback = .loading
                return .merge(fetchStudies(), fetchQuickFeedback(), fetchMyJoinRequests())

            case .refresh:
                // 로드된 콘텐츠는 유지 — pull-to-refresh 시 스켈레톤 대신 .refreshable 스피너가 로딩 표시
                if state.studies.value == nil { state.studies = .loading }
                return .merge(fetchStudies(), fetchQuickFeedback(), fetchMyJoinRequests())

            case .refreshQuickFeedback:
                return fetchQuickFeedback()

            case .studiesResponse(.success(let studies)):
                state.studies = .loaded(studies)
                return .none

            case .studiesResponse(.failure(let error)):
                state.studies = .failed(error)
                return .none

            case .quickFeedbackResponse(.success(let dashboard)):
                state.quickFeedback = .loaded(dashboard)
                return .none

            case .quickFeedbackResponse(.failure(let error)):
                state.quickFeedback = .failed(error)
                return .none

            case .quickFeedbackPrimaryTapped, .quickFeedbackHubTapped:
                return .none // 부모 내비게이션에서 처리

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

            case .practiceMirrorTapped:
                state.practiceMirror = PracticeMirrorFeature.State()
                return .none

            case .practiceMirror:
                return .none

            case .showJoinStudy(inviteCode: let code):
                state.joinStudy = JoinStudyFeature.State(inviteCode: code)
                return .none

            case .joinStudy(.presented(.delegate(.joinRequested))):
                state.joinStudy = nil
                // 방금 보낸 신청이 "승인 대기 중" 섹션에 바로 보이도록 재조회
                return fetchMyJoinRequests()

            case .myJoinRequestsResponse(.success(let requests)):
                state.myJoinRequests = requests
                return .none

            case .myJoinRequestsResponse(.failure):
                return .none

            case .cancelRequestTapped(let request):
                state.requestToCancel = request
                state.cancelConfirmAlert = AlertState {
                    TextState("가입 신청을 철회할까요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmCancel) {
                        TextState("철회")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("'\(request.studyName)' 가입 신청이 취소됩니다. 다시 신청하려면 초대 코드가 필요해요.")
                }
                return .none

            case .cancelConfirmAlert(.presented(.confirmCancel)):
                guard let request = state.requestToCancel else { return .none }
                state.requestToCancel = nil
                // Optimistic Update: 먼저 목록에서 제거하고 실패 시 재조회로 복구
                state.myJoinRequests.removeAll { $0.id == request.id }
                let client = studyClient
                return .run { send in
                    do {
                        try await client.cancelJoinRequest(request.id)
                    } catch {
                        await send(.cancelRequestFailed)
                    }
                }

            case .cancelConfirmAlert:
                state.requestToCancel = nil
                return .none

            case .cancelRequestFailed:
                return fetchMyJoinRequests()

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
        .ifLet(\.$cancelConfirmAlert, action: \.cancelConfirmAlert)
        .ifLet(\.$practiceMirror, action: \.practiceMirror) {
            PracticeMirrorFeature()
        }
    }

    private func fetchStudies() -> Effect<Action> {
        let client = studyClient
        return .run { send in
            do {
                await send(.studiesResponse(.success(try await client.fetchMyStudies())))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.studiesResponse(.failure(appError)))
            }
        }
    }

    private func fetchMyJoinRequests() -> Effect<Action> {
        let client = studyClient
        return .run { send in
            do {
                await send(.myJoinRequestsResponse(.success(try await client.fetchMyJoinRequests())))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.myJoinRequestsResponse(.failure(appError)))
            }
        }
    }

    private func fetchQuickFeedback() -> Effect<Action> {
        let client = quickFeedbackClient
        return .run { send in
            do {
                await send(.quickFeedbackResponse(.success(try await client.fetchDashboard())))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.quickFeedbackResponse(.failure(appError)))
            }
        }
    }
}
