import Foundation

struct StudyDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let ownerID: UUID
    let inviteCode: String
    let maxMembers: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerID = "owner_id"
        case inviteCode = "invite_code"
        case maxMembers = "max_members"
        case createdAt = "created_at"
    }
}

struct StudyMemberDTO: Codable, Sendable {
    let id: UUID
    let studyID: UUID
    let userID: UUID
    let userName: String
    let profileImageURL: String?
    let role: String
    let joinedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case studyID = "study_id"
        case userID = "user_id"
        case userName = "user_name"
        case profileImageURL = "profile_image_url"
        case role
        case joinedAt = "joined_at"
    }
}

struct StudyWithMembersDTO: Codable, Sendable {
    let study: StudyDTO
    let members: [StudyMemberDTO]
}
