import Foundation
import ComposableArchitecture
import Domain

public struct FeedbackCommentClient: Sendable {
    public var fetchComments: @Sendable (UUID) async throws -> [FeedbackComment]
    public var fetchLatestComments: @Sendable ([UUID]) async throws -> [UUID: FeedbackComment]
    public var createComment: @Sendable (CreateFeedbackCommentRequest) async throws -> FeedbackComment
    public var deleteComment: @Sendable (UUID) async throws -> Void

    public init(
        fetchComments: @escaping @Sendable (UUID) async throws -> [FeedbackComment],
        fetchLatestComments: @escaping @Sendable ([UUID]) async throws -> [UUID: FeedbackComment],
        createComment: @escaping @Sendable (CreateFeedbackCommentRequest) async throws -> FeedbackComment,
        deleteComment: @escaping @Sendable (UUID) async throws -> Void
    ) {
        self.fetchComments = fetchComments
        self.fetchLatestComments = fetchLatestComments
        self.createComment = createComment
        self.deleteComment = deleteComment
    }
}

extension FeedbackCommentClient: TestDependencyKey {
    public static let testValue = FeedbackCommentClient(
        fetchComments: unimplemented("\(Self.self).fetchComments"),
        fetchLatestComments: unimplemented("\(Self.self).fetchLatestComments"),
        createComment: unimplemented("\(Self.self).createComment"),
        deleteComment: unimplemented("\(Self.self).deleteComment")
    )
}

extension DependencyValues {
    public var feedbackCommentClient: FeedbackCommentClient {
        get { self[FeedbackCommentClient.self] }
        set { self[FeedbackCommentClient.self] = newValue }
    }
}
