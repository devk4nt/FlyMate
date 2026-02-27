import Foundation

public struct AppNotification: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let recipientID: UUID
    public let type: NotificationType
    public let title: String
    public let body: String
    public let referenceVideoID: UUID?
    public let referenceFeedbackID: UUID?
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
        self.isRead = isRead
        self.createdAt = createdAt
    }
}

public enum NotificationType: String, Equatable, Sendable, Hashable {
    case feedbackOnMyVideo = "feedback_on_my_video"
    case mentionedInFeedback = "mentioned_in_feedback"
    case replyOnMyFeedback = "reply_on_my_feedback"
    case mentionedInFeedbackComment = "mentioned_in_feedback_comment"
}
