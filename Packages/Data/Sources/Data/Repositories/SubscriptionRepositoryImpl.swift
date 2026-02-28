import Foundation
import Core
import Domain
import Supabase

public struct SubscriptionRepositoryImpl: SubscriptionRepository {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func fetchSubscription(userID: UUID) async throws -> Subscription {
        let dto: SubscriptionDTO = try await client.from(SupabaseConfig.Table.subscriptions)
            .select()
            .eq("user_id", value: userID)
            .single()
            .execute()
            .value

        return DTOMapper.toDomain(dto)
    }

    public func fetchEntitlements(userID: UUID) async throws -> Entitlement {
        let dto: EntitlementDTO = try await client.rpc(
            SupabaseConfig.RPC.getUserEntitlements,
            params: ["p_user_id": userID.uuidString]
        )
        .single()
        .execute()
        .value

        return DTOMapper.toDomain(dto)
    }

    public func fetchPlans() async throws -> [SubscriptionPlan] {
        let dtos: [SubscriptionPlanDTO] = try await client.from(SupabaseConfig.Table.subscriptionPlans)
            .select()
            .execute()
            .value

        return dtos.map(DTOMapper.toDomain)
    }

    public func verifyReceipt(_ receipt: VerifyReceiptRequest) async throws -> Entitlement {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        struct VerifyReceiptParams: Encodable {
            let transactionId: String
            let originalTransactionId: String
            let productId: String
            let purchaseDate: String
            let expiresDate: String
            let environment: String
        }

        let params = VerifyReceiptParams(
            transactionId: receipt.transactionID,
            originalTransactionId: receipt.originalTransactionID,
            productId: receipt.productID,
            purchaseDate: isoFormatter.string(from: receipt.purchaseDate),
            expiresDate: isoFormatter.string(from: receipt.expiresDate),
            environment: receipt.environment
        )

        let dto: EntitlementDTO = try await client.functions.invoke(
            SupabaseConfig.EdgeFunction.verifyReceipt,
            options: .init(body: params)
        )

        return DTOMapper.toDomain(dto)
    }

    public func checkFeatureLimit(userID: UUID, feature: String) async throws -> FeatureLimit {
        struct CheckParams: Encodable {
            let p_user_id: String
            let p_feature: String
        }

        let dto: FeatureLimitDTO = try await client.rpc(
            SupabaseConfig.RPC.checkFeatureLimit,
            params: CheckParams(
                p_user_id: userID.uuidString,
                p_feature: feature
            )
        )
        .single()
        .execute()
        .value

        return DTOMapper.toDomain(dto)
    }
}
