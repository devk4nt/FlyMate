import Foundation

struct ReportDTO: Codable, Sendable {
    let id: UUID
    let reporterID: UUID
    let targetType: String
    let targetID: UUID
    let reason: String
    let detail: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case reporterID = "reporter_id"
        case targetType = "target_type"
        case targetID = "target_id"
        case reason
        case detail
        case createdAt = "created_at"
    }
}
