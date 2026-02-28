import Foundation
import StoreKit
import ComposableArchitecture
import Domain

public struct SubscriptionClient: Sendable {
    // Supabase (서버)
    public var fetchEntitlements: @Sendable (UUID) async throws -> Entitlement
    public var fetchPlans: @Sendable () async throws -> [SubscriptionPlan]
    public var verifyReceipt: @Sendable (VerifyReceiptRequest) async throws -> Entitlement
    public var checkFeatureLimit: @Sendable (UUID, String) async throws -> FeatureLimit

    // StoreKit 2 (클라이언트)
    public var fetchProducts: @Sendable () async throws -> [Product]
    public var purchase: @Sendable (Product) async throws -> Transaction
    public var currentEntitlement: @Sendable () async -> Transaction?
    public var observeTransactionUpdates: @Sendable () -> AsyncStream<Transaction>
    public var restorePurchases: @Sendable () async throws -> Void

    public init(
        fetchEntitlements: @escaping @Sendable (UUID) async throws -> Entitlement,
        fetchPlans: @escaping @Sendable () async throws -> [SubscriptionPlan],
        verifyReceipt: @escaping @Sendable (VerifyReceiptRequest) async throws -> Entitlement,
        checkFeatureLimit: @escaping @Sendable (UUID, String) async throws -> FeatureLimit,
        fetchProducts: @escaping @Sendable () async throws -> [Product],
        purchase: @escaping @Sendable (Product) async throws -> Transaction,
        currentEntitlement: @escaping @Sendable () async -> Transaction?,
        observeTransactionUpdates: @escaping @Sendable () -> AsyncStream<Transaction>,
        restorePurchases: @escaping @Sendable () async throws -> Void
    ) {
        self.fetchEntitlements = fetchEntitlements
        self.fetchPlans = fetchPlans
        self.verifyReceipt = verifyReceipt
        self.checkFeatureLimit = checkFeatureLimit
        self.fetchProducts = fetchProducts
        self.purchase = purchase
        self.currentEntitlement = currentEntitlement
        self.observeTransactionUpdates = observeTransactionUpdates
        self.restorePurchases = restorePurchases
    }
}

extension SubscriptionClient: TestDependencyKey {
    public static let testValue = SubscriptionClient(
        fetchEntitlements: unimplemented("\(Self.self).fetchEntitlements"),
        fetchPlans: unimplemented("\(Self.self).fetchPlans"),
        verifyReceipt: unimplemented("\(Self.self).verifyReceipt"),
        checkFeatureLimit: unimplemented("\(Self.self).checkFeatureLimit"),
        fetchProducts: unimplemented("\(Self.self).fetchProducts"),
        purchase: unimplemented("\(Self.self).purchase"),
        currentEntitlement: unimplemented("\(Self.self).currentEntitlement"),
        observeTransactionUpdates: unimplemented("\(Self.self).observeTransactionUpdates", placeholder: .finished),
        restorePurchases: unimplemented("\(Self.self).restorePurchases")
    )
}

extension DependencyValues {
    public var subscriptionClient: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}
