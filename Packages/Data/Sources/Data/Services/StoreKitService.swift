import Foundation
import StoreKit
import Core

public struct StoreKitService: Sendable {
    public init() {}

    /// App Store에서 구독 상품 목록을 조회한다.
    public func fetchProducts() async throws -> [Product] {
        try await Product.products(for: AppConstants.SubscriptionProductID.all)
    }

    /// 구독 상품을 구매한다.
    public func purchase(_ product: Product) async throws -> Transaction {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction

        case .userCancelled:
            throw AppError.business(.purchaseFailed("사용자가 구매를 취소했습니다."))

        case .pending:
            throw AppError.business(.purchaseFailed("구매가 대기 중입니다. 잠시 후 다시 확인해주세요."))

        @unknown default:
            throw AppError.unexpected("알 수 없는 구매 결과입니다.")
        }
    }

    /// 현재 활성 구독의 최신 트랜잭션을 반환한다.
    public func currentEntitlement() async -> Transaction? {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                return transaction
            }
        }
        return nil
    }

    /// 트랜잭션 업데이트를 비동기 스트림으로 관찰한다.
    public func observeTransactionUpdates() -> AsyncStream<Transaction> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if let transaction = try? checkVerified(result) {
                        await transaction.finish()
                        continuation.yield(transaction)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// 이전 구매를 복원한다.
    public func restorePurchases() async throws {
        try await AppStore.sync()
    }

    // MARK: - Private

    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw AppError.business(.receiptVerificationFailed)
        case .verified(let transaction):
            return transaction
        }
    }
}
