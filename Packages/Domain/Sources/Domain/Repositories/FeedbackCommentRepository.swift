import Foundation

public protocol FeedbackCommentRepository: Sendable {
    /// 피드백에 달린 댓글 목록을 조회한다.
    func fetchComments(feedbackID: UUID) async throws -> [FeedbackComment]

    /// 여러 피드백의 최신 댓글 1개씩을 조회한다.
    func fetchLatestComments(feedbackIDs: [UUID]) async throws -> [UUID: FeedbackComment]

    /// 댓글을 작성한다.
    func createComment(_ request: CreateFeedbackCommentRequest) async throws -> FeedbackComment

    /// 댓글을 삭제한다.
    func deleteComment(id: UUID) async throws
}
