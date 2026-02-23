import Foundation

public protocol ReportRepository: Sendable {
    /// 신고를 등록한다.
    func createReport(_ request: CreateReportRequest) async throws -> Report

    /// 이미 신고한 대상인지 확인한다.
    func checkAlreadyReported(targetType: ReportTargetType, targetID: UUID) async throws -> Bool
}
