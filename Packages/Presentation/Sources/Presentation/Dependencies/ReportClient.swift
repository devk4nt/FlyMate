import Foundation
import ComposableArchitecture
import Domain

public struct ReportClient: Sendable {
    public var createReport: @Sendable (CreateReportRequest) async throws -> Report
    public var checkAlreadyReported: @Sendable (ReportTargetType, UUID) async throws -> Bool

    public init(
        createReport: @escaping @Sendable (CreateReportRequest) async throws -> Report,
        checkAlreadyReported: @escaping @Sendable (ReportTargetType, UUID) async throws -> Bool
    ) {
        self.createReport = createReport
        self.checkAlreadyReported = checkAlreadyReported
    }
}

extension ReportClient: TestDependencyKey {
    public static let testValue = ReportClient(
        createReport: unimplemented("\(Self.self).createReport"),
        checkAlreadyReported: unimplemented("\(Self.self).checkAlreadyReported")
    )
}

extension DependencyValues {
    public var reportClient: ReportClient {
        get { self[ReportClient.self] }
        set { self[ReportClient.self] = newValue }
    }
}
