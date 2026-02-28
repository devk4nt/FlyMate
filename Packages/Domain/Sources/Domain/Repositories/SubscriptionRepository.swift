import Foundation

public protocol SubscriptionRepository: Sendable {
    /// 사용자의 구독 정보를 조회한다.
    func fetchSubscription(userID: UUID) async throws -> Subscription

    /// 사용자의 권한(entitlement)을 조회한다.
    func fetchEntitlements(userID: UUID) async throws -> Entitlement

    /// 사용 가능한 구독 플랜 목록을 조회한다.
    func fetchPlans() async throws -> [SubscriptionPlan]

    /// App Store 영수증을 서버에서 검증하고 구독을 활성화한다.
    func verifyReceipt(_ receipt: VerifyReceiptRequest) async throws -> Entitlement

    /// 특정 기능의 제한을 확인한다.
    func checkFeatureLimit(userID: UUID, feature: String) async throws -> FeatureLimit
}

public struct VerifyReceiptRequest: Equatable, Sendable {
    public let transactionID: String
    public let originalTransactionID: String
    public let productID: String
    public let purchaseDate: Date
    public let expiresDate: Date
    public let environment: String

    public init(
        transactionID: String,
        originalTransactionID: String,
        productID: String,
        purchaseDate: Date,
        expiresDate: Date,
        environment: String
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.environment = environment
    }
}

public struct FeatureLimit: Equatable, Sendable {
    public let allowed: Bool
    public let current: Int
    public let max: Int
    public let feature: String

    public init(allowed: Bool, current: Int, max: Int, feature: String) {
        self.allowed = allowed
        self.current = current
        self.max = max
        self.feature = feature
    }
}
