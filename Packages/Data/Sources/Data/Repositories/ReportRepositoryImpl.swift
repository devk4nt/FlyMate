import Foundation
import Domain
import Supabase

public struct ReportRepositoryImpl: ReportRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func createReport(_ request: CreateReportRequest) async throws -> Report {
        let userID = try await client.auth.session.user.id

        struct InsertReport: Codable {
            let reporterID: UUID
            let targetType: String
            let targetID: UUID
            let reason: String
            let detail: String?
            enum CodingKeys: String, CodingKey {
                case reporterID = "reporter_id"
                case targetType = "target_type"
                case targetID = "target_id"
                case reason
                case detail
            }
        }

        let dto: ReportDTO = try await client.from(SupabaseConfig.Table.reports)
            .insert(InsertReport(
                reporterID: userID,
                targetType: request.targetType.rawValue,
                targetID: request.targetID,
                reason: request.reason.rawValue,
                detail: request.detail
            ))
            .select()
            .single()
            .execute()
            .value

        return DTOMapper.toDomain(dto)
    }

    public func checkAlreadyReported(targetType: ReportTargetType, targetID: UUID) async throws -> Bool {
        let userID = try await client.auth.session.user.id

        let dtos: [ReportDTO] = try await client.from(SupabaseConfig.Table.reports)
            .select()
            .eq("reporter_id", value: userID)
            .eq("target_type", value: targetType.rawValue)
            .eq("target_id", value: targetID)
            .limit(1)
            .execute()
            .value

        return !dtos.isEmpty
    }
}
