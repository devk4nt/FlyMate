import Foundation

public struct Subscription: Equatable, Sendable {
    public let id: UUID
    public let userID: UUID
    public let planID: String
    public let status: SubscriptionStatus
    public let originalTransactionID: String?
    public let latestTransactionID: String?
    public let productID: String?
    public let environment: SubscriptionEnvironment
    public let purchaseDate: Date?
    public let expiresDate: Date?
    public let isInBillingRetry: Bool
    public let autoRenewStatus: Bool
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        userID: UUID,
        planID: String,
        status: SubscriptionStatus,
        originalTransactionID: String? = nil,
        latestTransactionID: String? = nil,
        productID: String? = nil,
        environment: SubscriptionEnvironment = .production,
        purchaseDate: Date? = nil,
        expiresDate: Date? = nil,
        isInBillingRetry: Bool = false,
        autoRenewStatus: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.planID = planID
        self.status = status
        self.originalTransactionID = originalTransactionID
        self.latestTransactionID = latestTransactionID
        self.productID = productID
        self.environment = environment
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.isInBillingRetry = isInBillingRetry
        self.autoRenewStatus = autoRenewStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var isPremium: Bool {
        planID != "free" && status.isActive
    }

    public var isExpiringSoon: Bool {
        guard let expiresDate else { return false }
        return expiresDate.timeIntervalSinceNow < 3 * 24 * 60 * 60
    }
}

public enum SubscriptionStatus: String, Equatable, Sendable {
    case active
    case expired
    case revoked
    case gracePeriod = "grace_period"
    case billingRetry = "billing_retry"

    public var isActive: Bool {
        switch self {
        case .active, .gracePeriod, .billingRetry:
            return true
        case .expired, .revoked:
            return false
        }
    }
}

public enum SubscriptionEnvironment: String, Equatable, Sendable {
    case production
    case sandbox
}
