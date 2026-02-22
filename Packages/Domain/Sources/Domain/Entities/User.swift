import Foundation

public struct User: Equatable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let email: String
    public let name: String
    public let profileImageURL: URL?
    public let provider: AuthProvider
    public let createdAt: Date

    public init(
        id: UUID,
        email: String,
        name: String,
        profileImageURL: URL? = nil,
        provider: AuthProvider,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageURL = profileImageURL
        self.provider = provider
        self.createdAt = createdAt
    }
}

public enum AuthProvider: String, Equatable, Sendable, Codable {
    case apple
    case kakao
}
