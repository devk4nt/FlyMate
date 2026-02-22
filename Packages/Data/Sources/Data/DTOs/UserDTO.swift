import Foundation

struct UserDTO: Codable, Sendable {
    let id: UUID
    let email: String
    let name: String
    let profileImageURL: String?
    let provider: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageURL = "profile_image_url"
        case provider
        case createdAt = "created_at"
    }
}
