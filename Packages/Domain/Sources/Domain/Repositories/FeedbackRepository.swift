import Foundation

public protocol FeedbackRepository: Sendable {
    /// 영상에 달린 피드백 목록을 조회한다.
    func fetchFeedbacks(videoID: UUID) async throws -> [Feedback]

    /// 피드백을 작성한다.
    func createFeedback(_ request: CreateFeedbackRequest) async throws -> Feedback

    /// 받은 피드백 목록을 조회한다 (커서 기반 페이지네이션).
    func fetchReceivedFeedbacks(userID: UUID, cursor: Date?) async throws -> [Feedback]

    /// 작성한 피드백 목록을 조회한다 (커서 기반 페이지네이션).
    func fetchGivenFeedbacks(userID: UUID, cursor: Date?) async throws -> [Feedback]

    /// 영상의 피드백을 실시간 구독한다.
    func observeFeedbacks(videoID: UUID) -> AsyncStream<[Feedback]>

    /// 피드백을 삭제한다.
    func deleteFeedback(id: UUID) async throws
}
