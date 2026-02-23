import Foundation

public struct Report: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let reporterID: UUID
    public let targetType: ReportTargetType
    public let targetID: UUID
    public let reason: ReportReason
    public let detail: String?
    public let createdAt: Date

    public init(
        id: UUID,
        reporterID: UUID,
        targetType: ReportTargetType,
        targetID: UUID,
        reason: ReportReason,
        detail: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.reporterID = reporterID
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.detail = detail
        self.createdAt = createdAt
    }
}

public enum ReportTargetType: String, Equatable, Sendable, CaseIterable {
    case feedback
    case user
}

public enum ReportReason: String, Equatable, Sendable, CaseIterable {
    case spam
    case harassment
    case inappropriateContent
    case misinformation
    case other

    public var displayText: String {
        switch self {
        case .spam: return "스팸/광고"
        case .harassment: return "괴롭힘/욕설"
        case .inappropriateContent: return "부적절한 내용"
        case .misinformation: return "잘못된 정보"
        case .other: return "기타"
        }
    }
}

public struct CreateReportRequest: Equatable, Sendable {
    public let targetType: ReportTargetType
    public let targetID: UUID
    public let reason: ReportReason
    public let detail: String?

    public init(
        targetType: ReportTargetType,
        targetID: UUID,
        reason: ReportReason,
        detail: String? = nil
    ) {
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.detail = detail
    }
}
