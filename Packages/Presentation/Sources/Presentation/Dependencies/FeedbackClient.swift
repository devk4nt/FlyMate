import Foundation
import ComposableArchitecture
import Domain

public struct FeedbackClient: Sendable {
    public var fetchFeedbacks: @Sendable (UUID) async throws -> [Feedback]
    public var createFeedback: @Sendable (CreateFeedbackRequest) async throws -> Feedback
    public var fetchReceived: @Sendable (UUID, Date?) async throws -> [Feedback]
    public var fetchGiven: @Sendable (UUID, Date?) async throws -> [Feedback]
    public var observeFeedbacks: @Sendable (UUID) -> AsyncStream<[Feedback]>
    public var deleteFeedback: @Sendable (UUID) async throws -> Void

    public init(
        fetchFeedbacks: @escaping @Sendable (UUID) async throws -> [Feedback],
        createFeedback: @escaping @Sendable (CreateFeedbackRequest) async throws -> Feedback,
        fetchReceived: @escaping @Sendable (UUID, Date?) async throws -> [Feedback],
        fetchGiven: @escaping @Sendable (UUID, Date?) async throws -> [Feedback],
        observeFeedbacks: @escaping @Sendable (UUID) -> AsyncStream<[Feedback]>,
        deleteFeedback: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchFeedbacks = fetchFeedbacks
        self.createFeedback = createFeedback
        self.fetchReceived = fetchReceived
        self.fetchGiven = fetchGiven
        self.observeFeedbacks = observeFeedbacks
        self.deleteFeedback = deleteFeedback
    }
}

extension FeedbackClient: TestDependencyKey {
    public static let testValue = FeedbackClient(
        fetchFeedbacks: unimplemented("\(Self.self).fetchFeedbacks"),
        createFeedback: unimplemented("\(Self.self).createFeedback"),
        fetchReceived: unimplemented("\(Self.self).fetchReceived"),
        fetchGiven: unimplemented("\(Self.self).fetchGiven"),
        observeFeedbacks: unimplemented("\(Self.self).observeFeedbacks", placeholder: .finished),
        deleteFeedback: unimplemented("\(Self.self).deleteFeedback")
    )
}

extension DependencyValues {
    public var feedbackClient: FeedbackClient {
        get { self[FeedbackClient.self] }
        set { self[FeedbackClient.self] = newValue }
    }
}
