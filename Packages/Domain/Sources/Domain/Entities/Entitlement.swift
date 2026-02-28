import Foundation

public struct Entitlement: Equatable, Sendable {
    public let planID: String
    public let status: String
    public let expiresDate: Date?
    public let maxOwnedStudies: Int
    public let maxJoinedStudies: Int
    public let maxVideoDurationSeconds: Int
    public let maxStudyMembers: Int
    public let currentOwnedStudies: Int
    public let currentJoinedStudies: Int

    public init(
        planID: String,
        status: String,
        expiresDate: Date? = nil,
        maxOwnedStudies: Int,
        maxJoinedStudies: Int,
        maxVideoDurationSeconds: Int,
        maxStudyMembers: Int,
        currentOwnedStudies: Int,
        currentJoinedStudies: Int
    ) {
        self.planID = planID
        self.status = status
        self.expiresDate = expiresDate
        self.maxOwnedStudies = maxOwnedStudies
        self.maxJoinedStudies = maxJoinedStudies
        self.maxVideoDurationSeconds = maxVideoDurationSeconds
        self.maxStudyMembers = maxStudyMembers
        self.currentOwnedStudies = currentOwnedStudies
        self.currentJoinedStudies = currentJoinedStudies
    }

    // MARK: - Convenience

    public var isPremium: Bool {
        planID != "free"
    }

    public var canCreateStudy: Bool {
        currentOwnedStudies < maxOwnedStudies
    }

    public var canJoinStudy: Bool {
        currentJoinedStudies < maxJoinedStudies
    }

    public func canRecordVideo(durationSeconds: Int) -> Bool {
        durationSeconds <= maxVideoDurationSeconds
    }

    public var remainingOwnedStudies: Int {
        max(0, maxOwnedStudies - currentOwnedStudies)
    }

    public var remainingJoinedStudies: Int {
        max(0, maxJoinedStudies - currentJoinedStudies)
    }

    // MARK: - Default (Free)

    public static let free = Entitlement(
        planID: "free",
        status: "active",
        maxOwnedStudies: 1,
        maxJoinedStudies: 1,
        maxVideoDurationSeconds: 60,
        maxStudyMembers: 3,
        currentOwnedStudies: 0,
        currentJoinedStudies: 0
    )
}
