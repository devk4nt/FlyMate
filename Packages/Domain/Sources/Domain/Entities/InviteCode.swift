import Foundation

public struct InviteCode: Equatable, Sendable {
    public let code: String
    public let studyID: UUID
    public let studyName: String
    public let createdAt: Date
    public let expiresAt: Date
    public let isActive: Bool

    public init(
        code: String,
        studyID: UUID,
        studyName: String,
        createdAt: Date,
        expiresAt: Date,
        isActive: Bool
    ) {
        self.code = code
        self.studyID = studyID
        self.studyName = studyName
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isActive = isActive
    }

    public var isExpired: Bool {
        Date.now > expiresAt
    }

    public var isValid: Bool {
        isActive && !isExpired
    }
}
