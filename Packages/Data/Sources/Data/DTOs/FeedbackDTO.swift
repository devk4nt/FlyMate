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
    let mentionedUserIDs: [UUID]?
    let commentCount: Int?
    let acknowledgedAt: String?

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
        case mentionedUserIDs = "mentioned_user_ids"
        case commentCount = "comment_count"
        case acknowledgedAt = "acknowledged_at"
    }
}
