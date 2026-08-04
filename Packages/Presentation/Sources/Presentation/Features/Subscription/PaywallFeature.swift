import Foundation
import StoreKit
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct PaywallFeature {
    @ObservableState
    public struct State: Equatable {
        public var reason: PaywallReason
        public var products: [Product] = []
        public var purchaseInProgress = false
        public var currentUserID: UUID

        public init(reason: PaywallReason, currentUserID: UUID) {
            self.reason = reason
            self.currentUserID = currentUserID
        }

        public var monthlyProduct: Product? {
            products.first { $0.id == AppConstants.SubscriptionProductID.premiumMonthly }
        }

        public var yearlyProduct: Product? {
            products.first { $0.id == AppConstants.SubscriptionProductID.premiumYearly }
        }
    }

    public enum Action {
        case onAppear
        case productsLoaded([Product])
        case productsFailed(AppError)
        case purchaseTapped(Product)
        case purchaseCompleted(Entitlement)
        case purchaseFailed(AppError)
        case restoreTapped
        case restoreCompleted(Entitlement)
        case restoreFailed(AppError)
        case dismissTapped
    }

    @Dependency(\.subscriptionClient) private var subscriptionClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let client = subscriptionClient
                return .run { send in
                    do {
                        let products = try await client.fetchProducts()
                        await send(.productsLoaded(products))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.productsFailed(appError))
                    }
                }

            case .productsLoaded(let products):
                state.products = products
                return .none

            case .productsFailed:
                return .none

            case .purchaseTapped(let product):
                state.purchaseInProgress = true
                let client = subscriptionClient
                return .run { send in
                    do {
                        let transaction = try await client.purchase(product)
                        let receipt = VerifyReceiptRequest(
                            transactionID: String(transaction.id),
                            originalTransactionID: String(transaction.originalID),
                            productID: transaction.productID,
                            purchaseDate: transaction.purchaseDate,
                            expiresDate: transaction.expirationDate ?? transaction.purchaseDate,
                            environment: transaction.environment.rawValue
                        )
                        let entitlement = try await client.verifyReceipt(receipt)
                        await send(.purchaseCompleted(entitlement))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.purchaseFailed(appError))
                    }
                }

            case .purchaseCompleted:
                state.purchaseInProgress = false
                return .none

            case .purchaseFailed:
                state.purchaseInProgress = false
                return .none

            case .restoreTapped:
                state.purchaseInProgress = true
                let userID = state.currentUserID
                let client = subscriptionClient
                return .run { send in
                    do {
                        try await client.restorePurchases()
                        let entitlement = try await client.fetchEntitlements(userID)
                        await send(.restoreCompleted(entitlement))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.restoreFailed(appError))
                    }
                }

            case .restoreCompleted:
                state.purchaseInProgress = false
                return .none

            case .restoreFailed:
                state.purchaseInProgress = false
                return .none

            case .dismissTapped:
                return .none
            }
        }
    }
}

// MARK: - PaywallReason

public enum PaywallReason: Equatable, Sendable {
    case studyOwnerLimitReached
    case studyJoinLimitReached
    case videoDurationLimitReached
    case studyMemberLimitReached
    case general

    public var title: String {
        switch self {
        case .studyOwnerLimitReached:
            return "스터디 생성 한도 도달"
        case .studyJoinLimitReached:
            return "스터디 참여 한도 도달"
        case .videoDurationLimitReached:
            return "영상 길이 한도 도달"
        case .studyMemberLimitReached:
            return "스터디 멤버 한도 도달"
        case .general:
            return "프리미엄으로 업그레이드"
        }
    }

    public var message: String {
        switch self {
        case .studyOwnerLimitReached:
            return "무료 플랜에서는 스터디를 1개까지 만들 수 있습니다.\n프리미엄으로 업그레이드하면 5개까지 가능합니다."
        case .studyJoinLimitReached:
            return "무료 플랜에서는 스터디 1개에 참여할 수 있습니다.\n프리미엄으로 업그레이드하면 5개까지 가능합니다."
        case .videoDurationLimitReached:
            return "무료 플랜에서는 1분까지 촬영할 수 있습니다.\n프리미엄으로 업그레이드하면 3분까지 가능합니다."
        case .studyMemberLimitReached:
            return "무료 플랜에서는 스터디에 3명까지 참여할 수 있습니다.\n프리미엄으로 업그레이드하면 8명까지 가능합니다."
        case .general:
            return "프리미엄으로 업그레이드하고 더 많은 기능을 사용하세요."
        }
    }

    public var iconName: String {
        switch self {
        case .studyOwnerLimitReached, .studyJoinLimitReached:
            return "person.3.fill"
        case .videoDurationLimitReached:
            return "video.fill"
        case .studyMemberLimitReached:
            return "person.badge.plus"
        case .general:
            return "star.fill"
        }
    }
}
