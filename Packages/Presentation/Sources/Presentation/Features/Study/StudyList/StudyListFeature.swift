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
        @Presents public var recruitPromptAlert: AlertState<Action.RecruitPrompt>?
        @Presents public var createRecruit: RecruitCreateFeature.State?
        var requestToCancel: JoinRequest?
        /// 모집 글을 올리면 연결할 대상 — 스터디 생성 직후에만 채워진다
        var studyAwaitingRecruit: Study?

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
        case recruitPromptAlert(PresentationAction<RecruitPrompt>)
        case createRecruit(PresentationAction<RecruitCreateFeature.Action>)
        case linkStudyResponse(Result<RecruitPost, AppError>)

        public enum CancelConfirm: Equatable {
            case confirmCancel
        }

        public enum RecruitPrompt: Equatable {
            case writeRecruitPost
        }
    }

    @Dependency(\.studyClient) private var studyClient
    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient
    @Dependency(\.recruitClient) private var recruitClient

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
                analyticsClient.trackEvent(AnalyticsEvent.smileMirrorOpened, [:])
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

            case .createStudy(.presented(.studyCreated(let study))):
                state.createStudy = nil
                // 모집 글은 작성 시 전 유저에게 푸시가 나가는 유일한 경로라, 스터디를 만든
                // 직후가 유일하게 확실한 유도 시점이다. 거절해도 모집 탭에서 언제든 쓸 수 있다.
                state.studyAwaitingRecruit = study
                state.recruitPromptAlert = AlertState {
                    TextState("모집 글도 올릴까요?")
                } actions: {
                    ButtonState(action: .writeRecruitPost) {
                        TextState("올리기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("나중에")
                    }
                } message: {
                    TextState("'\(study.name)' 모집 글을 올리면 다른 사용자에게 알림이 가서 스터디원을 더 빨리 만날 수 있어요.")
                }
                return .send(.refresh)

            case .recruitPromptAlert(.presented(.writeRecruitPost)):
                guard let study = state.studyAwaitingRecruit else { return .none }
                state.createRecruit = RecruitCreateFeature.State(study: study)
                return .none

            case .recruitPromptAlert(.dismiss):
                state.studyAwaitingRecruit = nil
                return .none

            case .createRecruit(.presented(.delegate(.saved(let post)))):
                guard let study = state.studyAwaitingRecruit else { return .none }
                state.studyAwaitingRecruit = nil
                let client = recruitClient
                return .run { send in
                    do {
                        let linked = try await client.linkStudy(post.id, study.id)
                        await send(.linkStudyResponse(.success(linked)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.linkStudyResponse(.failure(appError)))
                    }
                }

            // 연결 실패해도 모집 글 자체는 올라갔다 — 글에서 '스터디 만들기'로 이어 붙일 수 있으므로
            // 홈에서 에러를 띄우지 않는다.
            case .linkStudyResponse:
                return .none

            case .createStudy, .joinStudy, .recruitPromptAlert, .createRecruit:
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
        .ifLet(\.$recruitPromptAlert, action: \.recruitPromptAlert)
        .ifLet(\.$createRecruit, action: \.createRecruit) {
            RecruitCreateFeature()
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
