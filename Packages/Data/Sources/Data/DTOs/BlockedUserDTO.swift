import Foundation

struct BlockedUserDTO: Codable, Sendable {
    let blockedID: UUID
    let blockedName: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case blockedID = "blocked_id"
        case blockedName = "blocked_name"
        case createdAt = "created_at"
    }
}
