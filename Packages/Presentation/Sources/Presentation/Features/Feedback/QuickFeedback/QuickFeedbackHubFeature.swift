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

            case .uploadTapped:
                return .none // 부모 내비게이션에서 처리

            case .errorDismissed:
                state.error = nil
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
        public let reviews: [QuickFeedbackReview]
        @Presents public var userActivity: MyActivityFeature.State?

        public init(request: QuickFeedbackRequest, reviews: [QuickFeedbackReview]) {
            self.request = request
            self.reviews = reviews
        }
    }

    public enum Action: Equatable {
        case reviewerProfileTapped(QuickFeedbackReview)
        case userActivity(PresentationAction<MyActivityFeature.Action>)
    }

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

            case .userActivity:
                return .none
            }
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
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
        @Presents public var userActivity: MyActivityFeature.State?

        public init(claimed: ClaimedQuickFeedback) {
            self.claimed = claimed
            self.focusArea = claimed.request.focusArea
        }

        public var isValid: Bool {
            positiveText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
                && improvementText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
        }
    }

    public enum Action: Equatable {
        case positiveTextChanged(String)
        case improvementTextChanged(String)
        case focusAreaSelected(QuickFeedbackFocusArea)
        case submitTapped
        case submitResponse(Result<QuickFeedbackReview, AppError>)
        case uploaderProfileTapped
        case userActivity(PresentationAction<MyActivityFeature.Action>)
        case errorDismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case submitted
        }
    }

    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient

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
            case .userActivity:
                return .none
            case .errorDismissed:
                state.error = nil
                return .none
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$userActivity, action: \.userActivity) {
            MyActivityFeature()
        }
    }
}
