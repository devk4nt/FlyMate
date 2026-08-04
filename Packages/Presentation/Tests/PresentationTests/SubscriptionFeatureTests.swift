import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

// StoreKit의 Product/Transaction은 테스트에서 인스턴스 생성이 불가능하므로,
// 상품 관련 경로는 빈 배열로, 구매 완료는 응답 액션 직접 전송으로 검증한다.
@MainActor
struct SubscriptionFeatureTests {
    private nonisolated static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000300")!

    @Test
    func 진입시_구독상태와_플랜_로드_성공() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in .premiumMock }
            $0.subscriptionClient.fetchPlans = { [.freeMock, .premiumMock] }
            $0.subscriptionClient.fetchProducts = { [] }
            $0.subscriptionClient.observeTransactionUpdates = { .finished }
        }

        await store.send(.onAppear) {
            $0.plans = .loading
        }

        await store.receive(\.productsLoaded)

        await store.receive(\.entitlementLoaded) {
            $0.entitlement = .premiumMock
        }

        await store.receive(\.plansLoaded) {
            $0.plans = .loaded([.freeMock, .premiumMock])
        }
    }

    @Test
    func 구독상태_로드_실패시_무료_플랜_폴백() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in throw AppError.network(.noConnection) }
            $0.subscriptionClient.fetchPlans = { [.freeMock] }
            $0.subscriptionClient.fetchProducts = { [] }
            $0.subscriptionClient.observeTransactionUpdates = { .finished }
        }

        await store.send(.onAppear) {
            $0.plans = .loading
        }

        await store.receive(\.productsLoaded)

        await store.receive(\.entitlementFailed) {
            $0.entitlement = .free
        }

        await store.receive(\.plansLoaded) {
            $0.plans = .loaded([.freeMock])
        }
    }

    @Test
    func 플랜_로드_실패() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in .free }
            $0.subscriptionClient.fetchPlans = { throw AppError.network(.timeout) }
            $0.subscriptionClient.fetchProducts = { [] }
            $0.subscriptionClient.observeTransactionUpdates = { .finished }
        }

        await store.send(.onAppear) {
            $0.plans = .loading
        }

        await store.receive(\.productsLoaded)

        await store.receive(\.entitlementLoaded) {
            $0.entitlement = .free
        }

        await store.receive(\.plansFailed) {
            $0.plans = .failed(.network(.timeout))
        }
    }

    @Test
    func 구매_완료시_구독상태_갱신() async {
        var state = SubscriptionFeature.State(currentUserID: Self.userID, entitlement: .free)
        state.purchaseInProgress = true

        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        }

        await store.send(.purchaseCompleted(.premiumMock)) {
            $0.purchaseInProgress = false
            $0.entitlement = .premiumMock
        }
    }

    @Test
    func 복원_성공시_구독상태_갱신() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID, entitlement: .free)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = {}
            $0.subscriptionClient.fetchEntitlements = { _ in .premiumMock }
        }

        await store.send(.restoreTapped) {
            $0.purchaseInProgress = true
        }

        await store.receive(\.restoreCompleted) {
            $0.purchaseInProgress = false
            $0.entitlement = .premiumMock
        }
    }

    @Test
    func 복원_실패() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID, entitlement: .free)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = { throw AppError.network(.noConnection) }
        }

        await store.send(.restoreTapped) {
            $0.purchaseInProgress = true
        }

        await store.receive(\.restoreFailed) {
            $0.purchaseInProgress = false
        }
    }

    @Test
    func 트랜잭션_업데이트시_구독상태_재조회() async {
        let store = TestStore(
            initialState: SubscriptionFeature.State(currentUserID: Self.userID, entitlement: .free)
        ) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in .premiumMock }
        }

        await store.send(.transactionUpdated)

        await store.receive(\.entitlementLoaded) {
            $0.entitlement = .premiumMock
        }
    }
}

// MARK: - Mock Data

private extension Entitlement {
    static let premiumMock = Entitlement(
        planID: "premium",
        status: "active",
        expiresDate: Date(timeIntervalSince1970: 1_800_000_000),
        maxOwnedStudies: 5,
        maxJoinedStudies: 5,
        maxVideoDurationSeconds: 180,
        maxStudyMembers: 8,
        currentOwnedStudies: 1,
        currentJoinedStudies: 1
    )
}

private extension SubscriptionPlan {
    static let freeMock = SubscriptionPlan(
        id: "free",
        name: "무료",
        maxOwnedStudies: 1,
        maxJoinedStudies: 1,
        maxVideoDurationSeconds: 60,
        maxStudyMembers: 3
    )

    static let premiumMock = SubscriptionPlan(
        id: "premium",
        name: "프리미엄",
        maxOwnedStudies: 5,
        maxJoinedStudies: 5,
        maxVideoDurationSeconds: 180,
        maxStudyMembers: 8
    )
}
