import Foundation

public struct UploadQuickFeedbackRequest: Equatable, Sendable {
    public let title: String
    public let videoData: Data
    public let durationSeconds: TimeInterval
    public let focusArea: QuickFeedbackFocusArea
    public let feedbackRequest: String?

    public init(
        title: String,
        videoData: Data,
        durationSeconds: TimeInterval,
        focusArea: QuickFeedbackFocusArea,
        feedbackRequest: String? = nil
    ) {
        self.title = title
        self.videoData = videoData
        self.durationSeconds = durationSeconds
        self.focusArea = focusArea
        self.feedbackRequest = feedbackRequest
    }
}

public struct CreateQuickFeedbackReviewRequest: Equatable, Sendable {
    public let assignmentID: UUID
    public let positiveText: String
    public let improvementText: String
    public let focusArea: QuickFeedbackFocusArea

    public init(
        assignmentID: UUID,
        positiveText: String,
        improvementText: String,
        focusArea: QuickFeedbackFocusArea
    ) {
        self.assignmentID = assignmentID
        self.positiveText = positiveText
        self.improvementText = improvementText
        self.focusArea = focusArea
    }
}

public struct ClaimedQuickFeedback: Equatable, Sendable {
    public let assignmentID: UUID
    public let request: QuickFeedbackRequest

    public init(assignmentID: UUID, request: QuickFeedbackRequest) {
        self.assignmentID = assignmentID
        self.request = request
    }
}

public protocol QuickFeedbackRepository: Sendable {
    func fetchDashboard() async throws -> QuickFeedbackDashboard
    func upload(
        _ request: UploadQuickFeedbackRequest,
        progress: @Sendable (Double) -> Void
    ) async throws -> QuickFeedbackRequest
    func claim(requestID: UUID) async throws -> ClaimedQuickFeedback
    func submitReview(_ request: CreateQuickFeedbackReviewRequest) async throws -> QuickFeedbackReview
    func closeRequest(id: UUID) async throws
}
