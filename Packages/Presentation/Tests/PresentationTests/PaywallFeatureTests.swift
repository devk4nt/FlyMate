import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

// StoreKit의 Product/Transaction은 테스트에서 인스턴스 생성이 불가능하므로,
// 상품 로드는 빈 배열/실패 경로만, 구매 성공/실패는 응답 액션 직접 전송으로 검증한다.
@MainActor
struct PaywallFeatureTests {
    private nonisolated static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000200")!

    @Test
    func 진입시_상품_로드() async {
        let store = TestStore(
            initialState: PaywallFeature.State(reason: .general, currentUserID: Self.userID)
        ) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchProducts = { [] }
        }

        await store.send(.onAppear)
        await store.receive(\.productsLoaded)
    }

    @Test
    func 상품_로드_실패() async {
        let store = TestStore(
            initialState: PaywallFeature.State(reason: .general, currentUserID: Self.userID)
        ) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchProducts = { throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear)
        await store.receive(\.productsFailed)
    }

    @Test
    func 구매_완료시_진행상태_해제() async {
        var state = PaywallFeature.State(reason: .videoDurationLimitReached, currentUserID: Self.userID)
        state.purchaseInProgress = true

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.purchaseCompleted(.premiumMock)) {
            $0.purchaseInProgress = false
        }
    }

    @Test
    func 구매_실패시_진행상태_해제() async {
        var state = PaywallFeature.State(reason: .general, currentUserID: Self.userID)
        state.purchaseInProgress = true

        let store = TestStore(initialState: state) {
            PaywallFeature()
        }

        await store.send(.purchaseFailed(.network(.noConnection))) {
            $0.purchaseInProgress = false
        }
    }

    @Test
    func 복원_성공() async {
        let store = TestStore(
            initialState: PaywallFeature.State(reason: .general, currentUserID: Self.userID)
        ) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = {}
            $0.subscriptionClient.fetchEntitlements = { _ in .premiumMock }
        }

        await store.send(.restoreTapped) {
            $0.purchaseInProgress = true
        }

        await store.receive(\.restoreCompleted) {
            $0.purchaseInProgress = false
        }
    }

    @Test
    func 복원_실패() async {
        let store = TestStore(
            initialState: PaywallFeature.State(reason: .general, currentUserID: Self.userID)
        ) {
            PaywallFeature()
        } withDependencies: {
            $0.subscriptionClient.restorePurchases = { throw AppError.network(.timeout) }
        }

        await store.send(.restoreTapped) {
            $0.purchaseInProgress = true
        }

        await store.receive(\.restoreFailed) {
            $0.purchaseInProgress = false
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
