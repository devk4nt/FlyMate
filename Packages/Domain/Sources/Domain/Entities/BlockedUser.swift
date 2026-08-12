import Foundation

/// 내가 차단한 사용자.
public struct BlockedUser: Equatable, Identifiable, Sendable, Hashable {
    /// 차단된 사용자의 ID
    public let id: UUID
    public let name: String
    public let profileImageURL: URL?
    public let blockedAt: Date

    public init(id: UUID, name: String, profileImageURL: URL?, blockedAt: Date) {
        self.id = id
        self.name = name
        self.profileImageURL = profileImageURL
        self.blockedAt = blockedAt
    }
}
