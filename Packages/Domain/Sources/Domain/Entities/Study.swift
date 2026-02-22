import Foundation

public struct Study: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String
    public let ownerID: UUID
    public let inviteCode: String
    public let maxMembers: Int
    public let members: [StudyMember]
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        description: String,
        ownerID: UUID,
        inviteCode: String,
        maxMembers: Int,
        members: [StudyMember],
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.ownerID = ownerID
        self.inviteCode = inviteCode
        self.maxMembers = maxMembers
        self.members = members
        self.createdAt = createdAt
    }

    public var isFull: Bool {
        members.count >= maxMembers
    }

    public var memberCount: Int {
        members.count
    }
}

public struct StudyMember: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let userID: UUID
    public let userName: String
    public let profileImageURL: URL?
    public let role: MemberRole
    public let joinedAt: Date

    public init(
        id: UUID,
        userID: UUID,
        userName: String,
        profileImageURL: URL? = nil,
        role: MemberRole,
        joinedAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.profileImageURL = profileImageURL
        self.role = role
        self.joinedAt = joinedAt
    }
}

public enum MemberRole: String, Equatable, Sendable, Codable {
    case owner
    case member
}
