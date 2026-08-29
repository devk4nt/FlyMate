import Foundation

public struct AppNotification: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let recipientID: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let referenceVideoID: UUID?
    public let referenceFeedbackID: UUID?
    public let referenceAnnouncementID: UUID?
    public let referenceQuickFeedbackRequestID: UUID?
    public let referenceRecruitPostID: UUID?
    public let referenceStudyID: UUID?
    public var isRead: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        recipientID: UUID,
        type: NotificationType,
        title: String,
        body: String,
        referenceVideoID: UUID? = nil,
        referenceFeedbackID: UUID? = nil,
        referenceAnnouncementID: UUID? = nil,
        referenceQuickFeedbackRequestID: UUID? = nil,
        referenceRecruitPostID: UUID? = nil,
        referenceStudyID: UUID? = nil,
        isRead: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.recipientID = recipientID
        self.type = type
        self.title = title
        self.body = body
        self.referenceVideoID = referenceVideoID
        self.referenceFeedbackID = referenceFeedbackID
        self.referenceAnnouncementID = referenceAnnouncementID
        self.referenceQuickFeedbackRequestID = referenceQuickFeedbackRequestID
        self.referenceRecruitPostID = referenceRecruitPostID
        self.referenceStudyID = referenceStudyID
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

public enum NotificationType: String, Equatable, Sendable, Hashable {
    case feedbackOnMyVideo = "feedback_on_my_video"
    case mentionedInFeedback = "mentioned_in_feedback"
    case replyOnMyFeedback = "reply_on_my_feedback"
    case mentionedInFeedbackComment = "mentioned_in_feedback_comment"
    case announcement
    case quickFeedbackReceived = "quick_feedback_received"
    case recruitPost = "recruit_post"
    case joinRequest = "join_request"
    case joinRequestApproved = "join_request_approved"
    case joinRequestRejected = "join_request_rejected"
}
