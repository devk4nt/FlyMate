import Foundation

public enum QuickFeedbackFocusArea: String, CaseIterable, Codable, Equatable, Sendable, Hashable {
    case expression
    case voice
    case answer
    case overall

    public var title: String {
        switch self {
        case .expression: "표정과 시선"
        case .voice: "목소리와 속도"
        case .answer: "답변 내용"
        case .overall: "전체적인 인상"
        }
    }
}

public enum QuickFeedbackRequestStatus: String, Codable, Equatable, Sendable, Hashable {
    case open
    case completed
    case expired
    case closed
}

public struct QuickFeedbackRequest: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let uploaderID: UUID
    public let uploaderName: String
    public let uploaderProfileURL: URL?
    public let title: String
    public let videoURL: URL?
    public let durationSeconds: TimeInterval
    public let focusArea: QuickFeedbackFocusArea
    public let feedbackRequest: String?
    public let status: QuickFeedbackRequestStatus
    public let feedbackCount: Int
    public let targetFeedbackCount: Int
    public let expiresAt: Date
    public let createdAt: Date

    public init(
        id: UUID,
        uploaderID: UUID,
        uploaderName: String,
        uploaderProfileURL: URL? = nil,
        title: String,
        videoURL: URL? = nil,
        durationSeconds: TimeInterval,
        focusArea: QuickFeedbackFocusArea,
        feedbackRequest: String? = nil,
        status: QuickFeedbackRequestStatus,
        feedbackCount: Int,
        targetFeedbackCount: Int,
        expiresAt: Date,
        createdAt: Date
    ) {
        self.id = id
        self.uploaderID = uploaderID
        self.uploaderName = uploaderName
        self.uploaderProfileURL = uploaderProfileURL
        self.title = title
        self.videoURL = videoURL
        self.durationSeconds = durationSeconds
        self.focusArea = focusArea
        self.feedbackRequest = feedbackRequest
        self.status = status
        self.feedbackCount = feedbackCount
        self.targetFeedbackCount = targetFeedbackCount
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

public struct QuickFeedbackReview: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let requestID: UUID
    public let reviewerID: UUID
    public let reviewerName: String
    public let reviewerProfileURL: URL?
    public let positiveText: String
    public let improvementText: String
    public let focusArea: QuickFeedbackFocusArea
    public let createdAt: Date

    public init(
        id: UUID,
        requestID: UUID,
        reviewerID: UUID,
        reviewerName: String,
        reviewerProfileURL: URL? = nil,
        positiveText: String,
        improvementText: String,
        focusArea: QuickFeedbackFocusArea,
        createdAt: Date
    ) {
        self.id = id
        self.requestID = requestID
        self.reviewerID = reviewerID
        self.reviewerName = reviewerName
        self.reviewerProfileURL = reviewerProfileURL
        self.positiveText = positiveText
        self.improvementText = improvementText
        self.focusArea = focusArea
        self.createdAt = createdAt
    }
}

public struct QuickFeedbackDashboard: Equatable, Sendable {
    public let pointBalance: Int
    public let myRequests: [QuickFeedbackRequest]
    public let availableRequests: [QuickFeedbackRequest]
    public let receivedReviews: [QuickFeedbackReview]

    public var latestRequest: QuickFeedbackRequest? {
        myRequests.first
    }

    public func reviews(for requestID: UUID) -> [QuickFeedbackReview] {
        receivedReviews.filter { $0.requestID == requestID }
    }

    public init(
        pointBalance: Int,
        myRequests: [QuickFeedbackRequest],
        availableRequests: [QuickFeedbackRequest],
        receivedReviews: [QuickFeedbackReview]
    ) {
        self.pointBalance = pointBalance
        self.myRequests = myRequests
        self.availableRequests = availableRequests
        self.receivedReviews = receivedReviews
    }

    public init(
        pointBalance: Int,
        latestRequest: QuickFeedbackRequest?,
        availableRequests: [QuickFeedbackRequest],
        receivedReviews: [QuickFeedbackReview]
    ) {
        self.pointBalance = pointBalance
        self.myRequests = latestRequest.map { [$0] } ?? []
        self.availableRequests = availableRequests
        self.receivedReviews = receivedReviews
    }
}
