import Foundation

struct NotificationDTO: Codable, Sendable {
    let id: UUID
    let recipientID: UUID
    let type: String
    let title: String
    let body: String
    let referenceVideoID: UUID?
    let referenceFeedbackID: UUID?
    let isRead: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case type
        case title
        case body
        case referenceVideoID = "reference_video_id"
        case referenceFeedbackID = "reference_feedback_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
