import Foundation
import StoreKit
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct SubscriptionFeature {
    @ObservableState
    public struct State: Equatable {
        public var entitlement: Entitlement?
        public var plans: LoadingState<[SubscriptionPlan]> = .idle
        public var products: [Product] = []
        public var purchaseInProgress = false
        public var currentUserID: UUID

        public init(currentUserID: UUID, entitlement: Entitlement? = nil) {
            self.currentUserID = currentUserID
            self.entitlement = entitlement
        }

        public var currentPlanID: String {
            entitlement?.planID ?? "free"
        }

        public var isPremium: Bool {
            entitlement?.isPremium ?? false
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
        case entitlementLoaded(Entitlement)
        case entitlementFailed(AppError)
        case plansLoaded([SubscriptionPlan])
        case plansFailed(AppError)
        case productsLoaded([Product])
        case productsFailed(AppError)
        case purchaseTapped(Product)
        case purchaseCompleted(Entitlement)
        case purchaseFailed(AppError)
        case restoreTapped
        case restoreCompleted(Entitlement)
        case restoreFailed(AppError)
        case transactionUpdated
    }

    private enum CancelID {
        case transactionUpdates
    }

    @Dependency(\.subscriptionClient) private var subscriptionClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let userID = state.currentUserID
                state.plans = .loading
                let client = subscriptionClient
                return .merge(
                    .run { send in
                        do {
                            let entitlement = try await client.fetchEntitlements(userID)
                            await send(.entitlementLoaded(entitlement))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.entitlementFailed(appError))
                        }
                    },
                    .run { send in
                        do {
                            let plans = try await client.fetchPlans()
                            await send(.plansLoaded(plans))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.plansFailed(appError))
                        }
                    },
                    .run { send in
                        do {
                            let products = try await client.fetchProducts()
                            await send(.productsLoaded(products))
                        } catch {
                            let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                            await send(.productsFailed(appError))
                        }
                    },
                    .run { send in
                        for await _ in client.observeTransactionUpdates() {
                            await send(.transactionUpdated)
                        }
                    }
                    .cancellable(id: CancelID.transactionUpdates)
                )

            case .entitlementLoaded(let entitlement):
                state.entitlement = entitlement
                return .none

            case .entitlementFailed:
                state.entitlement = .free
                return .none

            case .plansLoaded(let plans):
                state.plans = .loaded(plans)
                return .none

            case .plansFailed(let error):
                state.plans = .failed(error)
                return .none

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

            case .purchaseCompleted(let entitlement):
                state.purchaseInProgress = false
                state.entitlement = entitlement
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

            case .restoreCompleted(let entitlement):
                state.purchaseInProgress = false
                state.entitlement = entitlement
                return .none

            case .restoreFailed:
                state.purchaseInProgress = false
                return .none

            case .transactionUpdated:
                let userID = state.currentUserID
                let client = subscriptionClient
                return .run { send in
                    do {
                        let entitlement = try await client.fetchEntitlements(userID)
                        await send(.entitlementLoaded(entitlement))
                    } catch {
                        // 백그라운드 갱신 실패는 무시
                    }
                }
            }
        }
    }
}
