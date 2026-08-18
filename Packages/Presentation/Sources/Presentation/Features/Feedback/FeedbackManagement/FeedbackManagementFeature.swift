import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let userID: UUID
        public var selectedSegment: Segment = .pending
        public var pending: VideoFeedFeature.State
        public var received: FeedbackListFeature.State
        public var given: FeedbackListFeature.State
        public var quickFeedback: LoadingState<QuickFeedbackDashboard> = .idle
        @Presents public var quickFeedbackDetail: QuickFeedbackRequestDetailFeature.State?

        public init(userID: UUID) {
            self.userID = userID
            self.pending = VideoFeedFeature.State(scope: .pendingFeedback, currentUserID: userID)
            self.received = FeedbackListFeature.State(userID: userID, listType: .received)
            self.given = FeedbackListFeature.State(userID: userID, listType: .given)
        }

        public enum Segment: String, CaseIterable, Equatable {
            case pending = "할 일"
            case received = "받은 피드백"
            case given = "작성한 피드백"
        }
    }

    public enum Action {
        case segmentChanged(State.Segment)
        case pending(VideoFeedFeature.Action)
        case received(FeedbackListFeature.Action)
        case given(FeedbackListFeature.Action)
        case quickFeedbackResponse(Result<QuickFeedbackDashboard, AppError>)
        case quickFeedbackRequestTapped(UUID)
        case quickFeedbackDetail(PresentationAction<QuickFeedbackRequestDetailFeature.Action>)
    }

    @Dependency(\.quickFeedbackClient) private var quickFeedbackClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.pending, action: \.pending) {
            VideoFeedFeature()
        }
        Scope(state: \.received, action: \.received) {
            FeedbackListFeature()
        }
        Scope(state: \.given, action: \.given) {
            FeedbackListFeature()
        }
        Reduce { state, action in
            switch action {
            case .segmentChanged(let segment):
                state.selectedSegment = segment
                guard segment == .received else { return .none }
                return loadQuickFeedback(state: &state)

            case .quickFeedbackResponse(.success(let dashboard)):
                state.quickFeedback = .loaded(dashboard)
                return .none

            case .quickFeedbackResponse(.failure(let error)):
                state.quickFeedback = .failed(error)
                return .none

            case .quickFeedbackRequestTapped(let requestID):
                guard
                    case .loaded(let dashboard) = state.quickFeedback,
                    let request = dashboard.myRequests.first(where: { $0.id == requestID })
                else { return .none }
                state.quickFeedbackDetail = QuickFeedbackRequestDetailFeature.State(
                    request: request,
                    reviews: dashboard.reviews(for: requestID)
                )
                return .none

            case .pending, .received, .given, .quickFeedbackDetail:
                return .none
            }
        }
        .ifLet(\.$quickFeedbackDetail, action: \.quickFeedbackDetail) {
            QuickFeedbackRequestDetailFeature()
        }
    }

    private func loadQuickFeedback(state: inout State) -> Effect<Action> {
        if case .loading = state.quickFeedback { return .none }
        state.quickFeedback = .loading
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
