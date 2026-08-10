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

    /// 카카오 이메일 미동의 시 서버가 발급하는 내부용 이메일은 노출하지 않고 대체 문구 표시
    public var displayEmail: String {
        email.hasSuffix("@kakao.flymate.app") ? "카카오 계정" : email
    }
}

public enum AuthProvider: String, Equatable, Sendable, Codable {
    case apple
    case kakao
}
