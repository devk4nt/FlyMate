import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackEditFeature {
    @ObservableState
    public struct State: Equatable {
        public let feedback: Feedback
        public var content: String
        public var isSubmitting = false
        public var error: AppError?

        public init(feedback: Feedback) {
            self.feedback = feedback
            self.content = feedback.content
        }

        public var isValid: Bool {
            !content.isBlank
                && content.count <= AppConstants.maxFeedbackLength
                && content != feedback.content
        }
    }

    public enum Action: Equatable {
        case contentChanged(String)
        case saveTapped
        case saveResponse(Result<Feedback, AppError>)
        case cancelTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case feedbackUpdated(Feedback)
        }
    }

    @Dependency(\.feedbackClient) private var feedbackClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .contentChanged(let content):
                state.content = String(content.prefix(AppConstants.maxFeedbackLength))
                return .none

            case .saveTapped:
                guard state.isValid else { return .none }
                state.isSubmitting = true
                state.error = nil
                let client = feedbackClient
                let feedbackID = state.feedback.id
                let content = state.content
                return .run { send in
                    do {
                        let updated = try await client.updateFeedback(feedbackID, content)
                        await send(.saveResponse(.success(updated)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.saveResponse(.failure(appError)))
                    }
                }

            case .saveResponse(.success(let feedback)):
                state.isSubmitting = false
                return .send(.delegate(.feedbackUpdated(feedback)))

            case .saveResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .delegate:
                return .none
            }
        }
    }
}
