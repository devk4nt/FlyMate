import Foundation

struct QuickFeedbackRequestDTO: Codable, Sendable {
    let id: UUID
    let uploaderID: UUID
    let uploaderName: String
    let uploaderProfileURL: String?
    let title: String
    let videoPath: String
    let durationSeconds: Double
    let focusArea: String
    let feedbackRequest: String?
    let status: String
    let feedbackCount: Int
    let targetFeedbackCount: Int
    let expiresAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case uploaderID = "uploader_id"
        case uploaderName = "uploader_name"
        case uploaderProfileURL = "uploader_profile_url"
        case videoPath = "video_path"
        case durationSeconds = "duration_seconds"
        case focusArea = "focus_area"
        case feedbackRequest = "feedback_request"
        case feedbackCount = "feedback_count"
        case targetFeedbackCount = "target_feedback_count"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct ClaimedQuickFeedbackDTO: Codable, Sendable {
    let assignmentID: UUID
    let id: UUID
    let uploaderID: UUID
    let uploaderName: String
    let uploaderProfileURL: String?
    let title: String
    let videoPath: String
    let durationSeconds: Double
    let focusArea: String
    let feedbackRequest: String?
    let status: String
    let feedbackCount: Int
    let targetFeedbackCount: Int
    let expiresAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case assignmentID = "assignment_id"
        case uploaderID = "uploader_id"
        case uploaderName = "uploader_name"
        case uploaderProfileURL = "uploader_profile_url"
        case videoPath = "video_path"
        case durationSeconds = "duration_seconds"
        case focusArea = "focus_area"
        case feedbackRequest = "feedback_request"
        case feedbackCount = "feedback_count"
        case targetFeedbackCount = "target_feedback_count"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }

    func requestDTO(uploaderProfileURL: String? = nil) -> QuickFeedbackRequestDTO {
        QuickFeedbackRequestDTO(
            id: id,
            uploaderID: uploaderID,
            uploaderName: uploaderName,
            uploaderProfileURL: uploaderProfileURL ?? self.uploaderProfileURL,
            title: title,
            videoPath: videoPath,
            durationSeconds: durationSeconds,
            focusArea: focusArea,
            feedbackRequest: feedbackRequest,
            status: status,
            feedbackCount: feedbackCount,
            targetFeedbackCount: targetFeedbackCount,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}

struct QuickFeedbackReviewDTO: Codable, Sendable {
    let id: UUID
    let requestID: UUID
    let reviewerID: UUID
    let reviewerName: String
    let reviewerProfileURL: String?
    let positiveText: String
    let improvementText: String
    let focusArea: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case requestID = "request_id"
        case reviewerID = "reviewer_id"
        case reviewerName = "reviewer_name"
        case reviewerProfileURL = "reviewer_profile_url"
        case positiveText = "positive_text"
        case improvementText = "improvement_text"
        case focusArea = "focus_area"
        case createdAt = "created_at"
    }
}
