import Foundation

struct SubscriptionDTO: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let planID: String
    let status: String
    let originalTransactionID: String?
    let latestTransactionID: String?
    let productID: String?
    let environment: String?
    let purchaseDate: String?
    let expiresDate: String?
    let isInBillingRetry: Bool
    let autoRenewStatus: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case planID = "plan_id"
        case status
        case originalTransactionID = "original_transaction_id"
        case latestTransactionID = "latest_transaction_id"
        case productID = "product_id"
        case environment
        case purchaseDate = "purchase_date"
        case expiresDate = "expires_date"
        case isInBillingRetry = "is_in_billing_retry"
        case autoRenewStatus = "auto_renew_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SubscriptionPlanDTO: Codable, Sendable {
    let id: String
    let name: String
    let maxOwnedStudies: Int
    let maxJoinedStudies: Int
    let maxVideoDurationSeconds: Int
    let maxStudyMembers: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case maxOwnedStudies = "max_owned_studies"
        case maxJoinedStudies = "max_joined_studies"
        case maxVideoDurationSeconds = "max_video_duration_seconds"
        case maxStudyMembers = "max_study_members"
    }
}

struct EntitlementDTO: Codable, Sendable {
    let planID: String
    let status: String
    let expiresDate: String?
    let maxOwnedStudies: Int
    let maxJoinedStudies: Int
    let maxVideoDurationSeconds: Int
    let maxStudyMembers: Int
    let currentOwnedStudies: Int
    let currentJoinedStudies: Int

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case status
        case expiresDate = "expires_date"
        case maxOwnedStudies = "max_owned_studies"
        case maxJoinedStudies = "max_joined_studies"
        case maxVideoDurationSeconds = "max_video_duration_seconds"
        case maxStudyMembers = "max_study_members"
        case currentOwnedStudies = "current_owned_studies"
        case currentJoinedStudies = "current_joined_studies"
    }
}

struct FeatureLimitDTO: Codable, Sendable {
    let allowed: Bool
    let current: Int
    let max: Int
    let feature: String
}
