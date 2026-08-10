import Foundation

struct RecruitPostDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let field: String
    let meetingType: String
    let region: String?
    let schedule: String
    let startDate: String
    let endDate: String?
    let maxMembers: Int
    let deadline: String
    let requirement: String
    let contactMethod: String
    let linkURL: String?
    let authorID: UUID
    let authorName: String
    let status: String
    let commentCount: Int
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case field
        case meetingType = "meeting_type"
        case region
        case schedule
        case startDate = "start_date"
        case endDate = "end_date"
        case maxMembers = "max_members"
        case deadline
        case requirement
        case contactMethod = "contact_method"
        case linkURL = "link_url"
        case authorID = "author_id"
        case authorName = "author_name"
        case status
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RecruitCommentDTO: Codable, Sendable {
    let id: UUID
    let postID: UUID
    let parentID: UUID?
    let authorID: UUID
    let authorName: String
    let authorProfileURL: String?
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case postID = "post_id"
        case parentID = "parent_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case authorProfileURL = "author_profile_url"
        case content
        case createdAt = "created_at"
    }
}
