import Foundation

struct VideoDTO: Codable, Sendable {
    let id: UUID
    let studyID: UUID
    let uploaderID: UUID
    let uploaderName: String
    let title: String
    let videoURL: String
    let thumbnailURL: String?
    let durationSeconds: Double
    let feedbackCount: Int
    let focusPoints: String?
    let feedbackRequest: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case studyID = "study_id"
        case uploaderID = "uploader_id"
        case uploaderName = "uploader_name"
        case title
        case videoURL = "video_url"
        case thumbnailURL = "thumbnail_url"
        case durationSeconds = "duration_seconds"
        case feedbackCount = "feedback_count"
        case focusPoints = "focus_points"
        case feedbackRequest = "feedback_request"
        case createdAt = "created_at"
    }
}
