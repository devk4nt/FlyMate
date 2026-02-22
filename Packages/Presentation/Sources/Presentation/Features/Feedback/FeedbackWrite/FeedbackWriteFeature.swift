import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct FeedbackWriteFeature {
    @ObservableState
    public struct State: Equatable {
        public let videoID: UUID
        public var timestampSeconds: TimeInterval
        public var content = ""
        public var isSubmitting = false
        public var error: AppError?

        public init(videoID: UUID, timestampSeconds: TimeInterval) {
            self.videoID = videoID
            self.timestampSeconds = timestampSeconds
        }

        public var isValid: Bool {
            !content.isBlank && content.count <= AppConstants.maxFeedbackLength
        }
    }

    public enum Action: Equatable {
        case contentChanged(String)
        case submitTapped
        case submitResponse(Result<Feedback, AppError>)
        case feedbackSubmitted
        case cancelTapped
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

            case .submitTapped:
                guard state.isValid else { return .none }
                state.isSubmitting = true
                let request = CreateFeedbackRequest(
                    videoID: state.videoID,
                    content: state.content,
                    timestampSeconds: state.timestampSeconds
                )
                let client = feedbackClient
                return .run { send in
                    do {
                        let feedback = try await client.createFeedback(request)
                        await send(.submitResponse(.success(feedback)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.submitResponse(.failure(appError)))
                    }
                }

            case .submitResponse(.success):
                state.isSubmitting = false
                return .send(.feedbackSubmitted)

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.error = error
                return .none

            case .feedbackSubmitted:
                let dismiss = dismiss
                return .run { _ in await dismiss() }

            case .cancelTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }
            }
        }
    }
}
