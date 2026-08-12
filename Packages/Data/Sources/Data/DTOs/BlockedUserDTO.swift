import Foundation

struct BlockedUserDTO: Codable, Sendable {
    let blockedID: UUID
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case blockedID = "blocked_id"
        case createdAt = "created_at"
    }
}
