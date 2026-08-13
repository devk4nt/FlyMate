import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackListFeature {
    @ObservableState
    public struct State: Equatable {
        public let userID: UUID
        public let listType: ListType
        public var feedbacks = PaginatedState<Feedback>()
        public var loadingState: LoadingState<[Feedback]> = .idle
        @Presents public var report: ReportFeature.State?
        @Presents public var blockAlert: AlertState<Action.BlockAlert>?
        public var showToast = false
        public var toastMessage = ""

        public init(userID: UUID, listType: ListType) {
            self.userID = userID
            self.listType = listType
        }

        public enum ListType: Equatable, Sendable {
            case received
            case given
        }
    }

    public enum Action {
        case onAppear
        case refresh
        case feedbacksResponse(Result<[Feedback], AppError>)
        case loadMore
        case loadMoreResponse(Result<[Feedback], AppError>)
        case feedbackTapped(Feedback)
        case reportFeedbackTapped(Feedback)
        case reportUserTapped(Feedback)
        case report(PresentationAction<ReportFeature.Action>)
        case blockUserTapped(Feedback)
        case blockAlert(PresentationAction<BlockAlert>)
        case blockResponse(Result<UUID, AppError>)
        case dismissToast

        public enum BlockAlert: Equatable {
            case confirmBlock(userID: UUID, userName: String)
        }
    }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.blockClient) private var blockClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard case .idle = state.loadingState else { return .none }
                state.loadingState = .loading
                let client = feedbackClient
                return fetchFeedbacks(
                    client: client,
                    userID: state.userID,
                    listType: state.listType,
                    cursor: nil
                )

            case .refresh:
                state.loadingState = .loading
                state.feedbacks = PaginatedState<Feedback>()
                let client = feedbackClient
                return fetchFeedbacks(
                    client: client,
                    userID: state.userID,
                    listType: state.listType,
                    cursor: nil
                )

            case .feedbacksResponse(.success(let feedbacks)):
                state.feedbacks.items = feedbacks
                state.feedbacks.cursor = feedbacks.last?.createdAt
                state.feedbacks.hasMore = feedbacks.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(feedbacks)
                return .none

            case .feedbacksResponse(.failure(let error)):
                state.loadingState = .failed(error)
                return .none

            case .loadMore:
                guard !state.feedbacks.isLoadingMore, state.feedbacks.hasMore else { return .none }
                state.feedbacks.isLoadingMore = true
                let client = feedbackClient
                return fetchFeedbacks(
                    client: client,
                    userID: state.userID,
                    listType: state.listType,
                    cursor: state.feedbacks.cursor
                )

            case .loadMoreResponse(.success(let newFeedbacks)):
                state.feedbacks.isLoadingMore = false
                state.feedbacks.items.append(contentsOf: newFeedbacks)
                state.feedbacks.cursor = newFeedbacks.last?.createdAt
                state.feedbacks.hasMore = newFeedbacks.count >= AppConstants.defaultPageSize
                state.loadingState = .loaded(state.feedbacks.items)
                return .none

            case .loadMoreResponse(.failure):
                state.feedbacks.isLoadingMore = false
                return .none

            case .feedbackTapped:
                return .none // Handled by parent

            case .reportFeedbackTapped(let feedback):
                state.report = ReportFeature.State(
                    targetType: .feedback,
                    targetID: feedback.id
                )
                return .none

            case .reportUserTapped(let feedback):
                state.report = ReportFeature.State(
                    targetType: .user,
                    targetID: feedback.authorID
                )
                return .none

            case .report(.presented(.delegate(.reportSubmitted))):
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

            case .blockUserTapped(let feedback):
                state.blockAlert = AlertState {
                    TextState("\(feedback.authorName)님을 차단할까요?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmBlock(userID: feedback.authorID, userName: feedback.authorName)) {
                        TextState("차단하기")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("차단한 사용자의 영상과 피드백이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
                }
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
                // 차단한 사용자의 피드백을 목록에서 즉시 제거 (이후 조회는 서버 RLS가 필터)
                state.feedbacks.items.removeAll { $0.authorID == userID }
                state.loadingState = .loaded(state.feedbacks.items)
                state.toastMessage = "사용자를 차단했습니다"
                state.showToast = true
                return .none

            case .blockResponse(.failure):
                state.toastMessage = "차단에 실패했습니다. 다시 시도해 주세요."
                state.showToast = true
                return .none

            case .dismissToast:
                state.showToast = false
                return .none
            }
        }
        .ifLet(\.$report, action: \.report) {
            ReportFeature()
        }
        .ifLet(\.$blockAlert, action: \.blockAlert)
    }

    private func fetchFeedbacks(
        client: FeedbackClient,
        userID: UUID,
        listType: State.ListType,
        cursor: Date?
    ) -> Effect<Action> {
        .run { send in
            do {
                let feedbacks: [Feedback]
                switch listType {
                case .received:
                    feedbacks = try await client.fetchReceived(userID, cursor)
                case .given:
                    feedbacks = try await client.fetchGiven(userID, cursor)
                }
                if cursor == nil {
                    await send(.feedbacksResponse(.success(feedbacks)))
                } else {
                    await send(.loadMoreResponse(.success(feedbacks)))
                }
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                if cursor == nil {
                    await send(.feedbacksResponse(.failure(appError)))
                } else {
                    await send(.loadMoreResponse(.failure(appError)))
                }
            }
        }
    }
}
