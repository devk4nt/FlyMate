import Foundation

public struct InviteCode: Equatable, Sendable {
    public let code: String
    public let studyID: UUID
    public let studyName: String
    public let createdAt: Date
    public let expiresAt: Date?

    public init(
        code: String,
        studyID: UUID,
        studyName: String,
        createdAt: Date,
        expiresAt: Date? = nil
    ) {
        self.code = code
        self.studyID = studyID
        self.studyName = studyName
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date.now > expiresAt
    }
}
