import Foundation
import Domain
import Supabase

public struct InterviewInsightRepositoryImpl: InterviewInsightRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func generateInsight(request: InterviewInsightRequest) async throws -> InterviewInsight {
        struct InsightResponse: Decodable {
            let insight: InterviewInsight
        }

        let response: InsightResponse = try await client.functions.invoke(
            SupabaseConfig.EdgeFunction.interviewInsight,
            options: .init(body: request)
        )
        return response.insight
    }
}
