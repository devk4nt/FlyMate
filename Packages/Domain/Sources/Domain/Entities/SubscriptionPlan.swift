import Foundation

public struct SubscriptionPlan: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let maxOwnedStudies: Int
    public let maxJoinedStudies: Int
    public let maxVideoDurationSeconds: Int
    public let maxStudyMembers: Int

    public init(
        id: String,
        name: String,
        maxOwnedStudies: Int,
        maxJoinedStudies: Int,
        maxVideoDurationSeconds: Int,
        maxStudyMembers: Int
    ) {
        self.id = id
        self.name = name
        self.maxOwnedStudies = maxOwnedStudies
        self.maxJoinedStudies = maxJoinedStudies
        self.maxVideoDurationSeconds = maxVideoDurationSeconds
        self.maxStudyMembers = maxStudyMembers
    }

    public var isPremium: Bool {
        id != "free"
    }

    public var videoDurationMinutes: Int {
        maxVideoDurationSeconds / 60
    }
}
