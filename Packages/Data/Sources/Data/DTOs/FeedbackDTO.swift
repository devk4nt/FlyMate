import Foundation

struct FeedbackDTO: Codable, Sendable {
    let id: UUID
    let videoID: UUID
    let studyID: UUID
    let authorID: UUID
    let authorName: String
    let authorProfileURL: String?
    let content: String
    let timestampSeconds: Double
    let createdAt: String
    let mentionedUserID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case studyID = "study_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case authorProfileURL = "author_profile_url"
        case content
        case timestampSeconds = "timestamp_seconds"
        case createdAt = "created_at"
        case mentionedUserID = "mentioned_user_id"
    }
}
