import Foundation

struct FeedbackCommentDTO: Codable, Sendable {
    let id: UUID
    let feedbackID: UUID
    let studyID: UUID
    let authorID: UUID
    let authorName: String
    let authorProfileURL: String?
    let content: String
    let mentionedUserIDs: [UUID]?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case feedbackID = "feedback_id"
        case studyID = "study_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case authorProfileURL = "author_profile_url"
        case content
        case mentionedUserIDs = "mentioned_user_ids"
        case createdAt = "created_at"
    }
}
