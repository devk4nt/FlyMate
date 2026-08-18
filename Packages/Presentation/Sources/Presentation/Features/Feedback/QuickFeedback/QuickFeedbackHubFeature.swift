import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct QuickFeedbackHubFeature {
    @ObservableState
    public struct State: Equatable {
        public var dashboard: LoadingState<QuickFeedbackDashboard> = .idle
        public var isClaiming = false
        public var error: AppError?
        public var showToast = false
        public var toastMessage = ""
        @Presents public var review: QuickFeedbackReviewFeature.State?
        @Presents public var requestDetail: QuickFeedbackRequestDetailFeature.State?

        public init() {}
    }

    public enum Action {
        case onAppear
        case refresh
        case dashboardResponse(Result<QuickFeedbackDashboard, AppError>)
        case startFeedbackTapped
        case claimResponse(Result<ClaimedQuickFeedback, AppError>)
        case closeRequestTapped(UUID)
        case closeRequestResponse(Result<Void, AppError>)
        case requestHistoryTapped(UUID)
        case uploadTapped
        case errorDismissed
        case dismissToast
        case review(PresentationAction<QuickFeedbackReviewFeature.Action>)
        case requestDetail(PresentationAction<QuickFeedbackRequestDetailFeature.Action>)
    }

    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.dashboard else { return .none }
                state.dashboard = .loading
                return fetchDashboard()

            case .refresh:
                return fetchDashboard()

            case .dashboardResponse(.success(let dashboard)):
                state.dashboard = .loaded(dashboard)
                return .none

            case .dashboardResponse(.failure(let error)):
                state.dashboard = .failed(error)
                return .none

            case .startFeedbackTapped:
                guard
                    !state.isClaiming,
                    case .loaded(let dashboard) = state.dashboard,
                    let requestID = dashboard.availableRequests.first?.id
                else { return .none }
                state.isClaiming = true
                state.error = nil
                let client = quickFeedbackClient
                return .run { send in
                    do {
                        await send(.claimResponse(.success(try await client.claim(requestID))))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.claimResponse(.failure(appError)))
                    }
                }

            case .claimResponse(.success(let claimed)):
                state.isClaiming = false
                state.review = QuickFeedbackReviewFeature.State(claimed: claimed)
                return .none

            case .claimResponse(.failure(let error)):
                state.isClaiming = false
                state.error = error
                return .send(.refresh)

            case .closeRequestTapped(let requestID):
                let client = quickFeedbackClient
                return .run { send in
                    do {
                        try await client.closeRequest(requestID)
                        await send(.closeRequestResponse(.success(())))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.closeRequestResponse(.failure(appError)))
                    }
                }

            case .closeRequestResponse(.success):
                return .send(.refresh)

            case .closeRequestResponse(.failure(let error)):
                state.error = error
                return .none

            case .requestHistoryTapped(let requestID):
                guard
                    case .loaded(let dashboard) = state.dashboard,
                    let request = dashboard.myRequests.first(where: { $0.id == requestID })
                else { return .none }
                state.requestDetail = QuickFeedbackRequestDetailFeature.State(
                    request: request,
                    reviews: dashboard.reviews(for: requestID)
                )
                return .none

            case .review(.presented(.delegate(.submitted))):
                state.review = nil
                return .send(.refresh)

            case .review(.presented(.delegate(.moderationCompleted(let message)))):
                state.review = nil
                state.toastMessage = message
                state.showToast = true
                return .send(.refresh)

            case .requestDetail(.presented(.report(.presented(.delegate(.reportSubmitted))))),
                 .requestDetail(.presented(.blockResponse(.success))):
                return .send(.refresh)

            case .uploadTapped:
                return .none // 부모 내비게이션에서 처리

            case .errorDismissed:
                state.error = nil
                return .none

            case .dismissToast:
                state.showToast = false
                return .none

            case .review, .requestDetail:
                return .none
            }
        }
        .ifLet(\.$review, action: \.review) {
            QuickFeedbackReviewFeature()
        }
        .ifLet(\.$requestDetail, action: \.requestDetail) {
            QuickFeedbackRequestDetailFeature()
        }
    }

    private func fetchDashboard() -> Effect<Action> {
        let client = quickFeedbackClient
        return .run { send in
            do {
                await send(.dashboardResponse(.success(try await client.fetchDashboard())))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.dashboardResponse(.failure(appError)))
            }
        }
    }
}

@Reducer
public struct QuickFeedbackRequestDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let request: QuickFeedbackRequest
        public var reviews: [QuickFeedbackReview]
        public var showToast = false
        public var toastMessage = ""
        @Presents public var report: ReportFeature.State?
        @Presents public var userActivity: MyActivityFeature.State?
        @Presents public var blockAlert: AlertState<Action.BlockAlert>?

        public init(request: QuickFeedbackRequest, reviews: [QuickFeedbackReview]) {
            self.request = request
            self.reviews = reviews
        }
    }

    public enum Action {
        case reviewerProfileTapped(QuickFeedbackReview)
        case reportReviewTapped(QuickFeedbackReview)
        case reportUserTapped(QuickFeedbackReview)
        case report(PresentationAction<ReportFeature.Action>)
        case blockUserTapped(QuickFeedbackReview)
        case blockAlert(PresentationAction<BlockAlert>)
        case blockResponse(Result<UUID, AppError>)
        case dismissToast
        case userActivity(PresentationAction<MyActivityFeature.Action>)

        public enum BlockAlert: Equatable {
            case confirmBlock(userID: UUID, userName: String)
        }
    }

    @Dependency(\.blockClient) private var blockClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .reviewerProfileTapped(let review):
                state.userActivity = MyActivityFeature.State(
                    userID: review.reviewerID,
                    userName: review.reviewerName,
                    profileImageURL: review.reviewerProfileURL
                )
                return .none

            case .reportReviewTapped(let review):
                state.report = ReportFeature.State(
                    targetType: .quickFeedbackReview,
                    targetID: review.id
                )
                return .none

            case .reportUserTapped(let review):
                state.report = ReportFeature.State(targetType: .user, targetID: review.reviewerID)
                return .none

            case .report(.presented(.delegate(.reportSubmitted))):
                if state.report?.targetType == .quickFeedbackReview,
                   let reviewID = state.report?.targetID {
                    state.reviews.removeAll { $0.id == reviewID }
                }
                state.report = nil
                state.toastMessage = "신고가 접수되었습니다"
                state.showToast = true
                return .none

            case .report(.presented(.delegate(.alreadyReported))):
                state.report = nil
                state.toastMessage = "이미 신고한 항목입니다"
                state.showToast = true
                return .none

            case .report:
                return .none

            case .blockUserTapped(let review):
                state.blockAlert = Self.blockAlert(userID: review.reviewerID, userName: review.reviewerName)
                return .none

            case .blockAlert(.presented(.confirmBlock(let userID, let userName))):
                let client = blockClient
                return .run { send in
                    do {
                        try await client.blockUser(userID, userName)
                        await send(.blockResponse(.success(userID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.blockResponse(.failure(appError)))
                    }
                }

            case .blockAlert:
                return .none

            case .blockResponse(.success(let userID)):
                state.reviews.removeAll { $0.reviewerID == userID }
                state.toastMessage = "사용자를 차단했습니다"
                state.showToast = true
                return .none

            case .blockResponse(.failure(let error)):
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none

            case .dismissToast:
                state.showToast = false
                return .none

            case .userActivity:
                return .none
            }
        }
        .ifLet(\.$report, action: \.report) {
            ReportFeature()
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
        }
        .ifLet(\.$blockAlert, action: \.blockAlert)
    }

    private static func blockAlert(userID: UUID, userName: String) -> AlertState<Action.BlockAlert> {
        AlertState {
            TextState("\(userName)님을 차단할까요?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmBlock(userID: userID, userName: userName)) {
                TextState("차단하기")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        } message: {
            TextState("차단한 사용자의 영상과 피드백이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
        }
    }
}

@Reducer
public struct QuickFeedbackReviewFeature {
    @ObservableState
    public struct State: Equatable {
        public let claimed: ClaimedQuickFeedback
        public var positiveText = ""
        public var improvementText = ""
        public var focusArea: QuickFeedbackFocusArea
        public var isSubmitting = false
        public var error: AppError?
        public var showToast = false
        public var toastMessage = ""
        @Presents public var report: ReportFeature.State?
        @Presents public var userActivity: MyActivityFeature.State?
        @Presents public var blockAlert: AlertState<Action.BlockAlert>?

        public init(claimed: ClaimedQuickFeedback) {
            self.claimed = claimed
            self.focusArea = claimed.request.focusArea
        }

        public var isValid: Bool {
            positiveText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
                && improvementText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
        }
    }

    public enum Action {
        case positiveTextChanged(String)
        case improvementTextChanged(String)
        case focusAreaSelected(QuickFeedbackFocusArea)
        case submitTapped
        case submitResponse(Result<QuickFeedbackReview, AppError>)
        case uploaderProfileTapped
        case reportRequestTapped
        case reportUploaderTapped
        case report(PresentationAction<ReportFeature.Action>)
        case blockUploaderTapped
        case blockAlert(PresentationAction<BlockAlert>)
        case blockResponse(Result<UUID, AppError>)
        case dismissToast
        case userActivity(PresentationAction<MyActivityFeature.Action>)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case submitted
            case moderationCompleted(String)
        }

        public enum BlockAlert: Equatable {
            case confirmBlock(userID: UUID, userName: String)
        }
    }

    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient
    @Dependency(\.blockClient) private var blockClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .positiveTextChanged(let text):
                state.positiveText = text
                return .none
            case .improvementTextChanged(let text):
                state.improvementText = text
                return .none
            case .focusAreaSelected(let area):
                state.focusArea = area
                return .none
            case .submitTapped:
                guard state.isValid, !state.isSubmitting else { return .none }
                state.isSubmitting = true
                state.error = nil
                let request = CreateQuickFeedbackReviewRequest(
                    assignmentID: state.claimed.assignmentID,
                    positiveText: state.positiveText,
                    improvementText: state.improvementText,
                    focusArea: state.focusArea
                )
                let client = quickFeedbackClient
                return .run { send in
                    do {
                        await send(.submitResponse(.success(try await client.submitReview(request))))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }
            case .submitResponse(.success):
                state.isSubmitting = false
                return .send(.delegate(.submitted))
            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none
            case .uploaderProfileTapped:
                let uploader = state.claimed.request
                state.userActivity = MyActivityFeature.State(
                    userID: uploader.uploaderID,
                    userName: uploader.uploaderName,
                    profileImageURL: uploader.uploaderProfileURL
                )
                return .none
            case .reportRequestTapped:
                state.report = ReportFeature.State(
                    targetType: .quickFeedbackRequest,
                    targetID: state.claimed.request.id
                )
                return .none
            case .reportUploaderTapped:
                state.report = ReportFeature.State(
                    targetType: .user,
                    targetID: state.claimed.request.uploaderID
                )
                return .none
            case .report(.presented(.delegate(.reportSubmitted))):
                let reportedRequest = state.report?.targetType == .quickFeedbackRequest
                state.report = nil
                guard reportedRequest else {
                    state.toastMessage = "신고가 접수되었습니다"
                    state.showToast = true
                    return .none
                }
                return cancelAssignment(
                    state.claimed.assignmentID,
                    message: "영상을 신고했습니다"
                )
            case .report(.presented(.delegate(.alreadyReported))):
                let reportedRequest = state.report?.targetType == .quickFeedbackRequest
                state.report = nil
                guard reportedRequest else {
                    state.toastMessage = "이미 신고한 항목입니다"
                    state.showToast = true
                    return .none
                }
                return cancelAssignment(
                    state.claimed.assignmentID,
                    message: "이미 신고한 영상입니다"
                )
            case .report:
                return .none
            case .blockUploaderTapped:
                let uploader = state.claimed.request
                state.blockAlert = Self.blockAlert(
                    userID: uploader.uploaderID,
                    userName: uploader.uploaderName
                )
                return .none
            case .blockAlert(.presented(.confirmBlock(let userID, let userName))):
                let block = blockClient
                let quickFeedback = quickFeedbackClient
                let assignmentID = state.claimed.assignmentID
                return .run { send in
                    do {
                        try await block.blockUser(userID, userName)
                        try? await quickFeedback.cancelAssignment(assignmentID)
                        await send(.blockResponse(.success(userID)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.blockResponse(.failure(appError)))
                    }
                }
            case .blockAlert:
                return .none
            case .blockResponse(.success):
                return .send(.delegate(.moderationCompleted("사용자를 차단했습니다")))
            case .blockResponse(.failure(let error)):
                state.toastMessage = error.localizedDescription
                state.showToast = true
                return .none
            case .dismissToast:
                state.showToast = false
                return .none
            case .userActivity:
                return .none
            case .errorDismissed:
                state.error = nil
                return .none
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$report, action: \.report) {
            ReportFeature()
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
        }
        .ifLet(\.$blockAlert, action: \.blockAlert)
    }

    private func cancelAssignment(_ assignmentID: UUID, message: String) -> Effect<Action> {
        let client = quickFeedbackClient
        return .run { send in
            try? await client.cancelAssignment(assignmentID)
            await send(.delegate(.moderationCompleted(message)))
        }
    }

    private static func blockAlert(userID: UUID, userName: String) -> AlertState<Action.BlockAlert> {
        AlertState {
            TextState("\(userName)님을 차단할까요?")
        } actions: {
            ButtonState(role: .destructive, action: .confirmBlock(userID: userID, userName: userName)) {
                TextState("차단하기")
            }
            ButtonState(role: .cancel) {
                TextState("취소")
            }
        } message: {
            TextState("차단하면 이 영상 배정이 취소되고, 앞으로 서로의 빠른 피드백 콘텐츠가 표시되지 않아요.")
        }
    }
}
