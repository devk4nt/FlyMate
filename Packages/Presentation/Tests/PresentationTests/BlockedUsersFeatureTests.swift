import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct BlockedUsersFeatureTests {

    // MARK: - 목록 로딩

    @Test
    func 차단_목록_로딩_성공() async {
        let store = TestStore(initialState: BlockedUsersFeature.State()) {
            BlockedUsersFeature()
        } withDependencies: {
            $0.blockClient.fetchBlockedUsers = { [.mock] }
        }

        await store.send(.onAppear) {
            $0.blockedUsers = .loading
        }

        await store.receive(\.blockedUsersResponse.success) {
            $0.blockedUsers = .loaded([.mock])
        }
    }

    @Test
    func 차단_목록_로딩_실패시_failed_상태_및_재시도() async {
        let hasFailed = LockIsolated(false)
        let store = TestStore(initialState: BlockedUsersFeature.State()) {
            BlockedUsersFeature()
        } withDependencies: {
            $0.blockClient.fetchBlockedUsers = {
                if hasFailed.value {
                    return [.mock]
                }
                hasFailed.setValue(true)
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.onAppear) {
            $0.blockedUsers = .loading
        }

        await store.receive(\.blockedUsersResponse.failure) {
            $0.blockedUsers = .failed(.network(.serverError(statusCode: 500)))
        }

        await store.send(.retryTapped) {
            $0.blockedUsers = .loading
        }

        await store.receive(\.blockedUsersResponse.success) {
            $0.blockedUsers = .loaded([.mock])
        }
    }

    // MARK: - 차단 해제

    @Test
    func 차단_해제_성공시_목록에서_제거_및_토스트() async {
        var state = BlockedUsersFeature.State()
        state.blockedUsers = .loaded([.mock])

        let unblockedID = LockIsolated<UUID?>(nil)
        let store = TestStore(initialState: state) {
            BlockedUsersFeature()
        } withDependencies: {
            $0.blockClient.unblockUser = { unblockedID.setValue($0) }
        }

        await store.send(.unblockTapped(.mock))

        await store.receive(\.unblockResponse.success) {
            $0.blockedUsers = .loaded([])
            $0.showToast = true
            $0.toastMessage = "차단을 해제했습니다"
        }

        #expect(unblockedID.value == BlockedUser.mock.id)
    }

    @Test
    func 차단_해제_실패시_목록_유지_및_에러_토스트() async {
        var state = BlockedUsersFeature.State()
        state.blockedUsers = .loaded([.mock])

        let store = TestStore(initialState: state) {
            BlockedUsersFeature()
        } withDependencies: {
            $0.blockClient.unblockUser = { _ in
                throw AppError.network(.noConnection)
            }
        }

        await store.send(.unblockTapped(.mock))

        await store.receive(\.unblockResponse.failure) {
            $0.showToast = true
            $0.toastMessage = "차단 해제에 실패했습니다. 다시 시도해 주세요."
        }

        #expect(store.state.blockedUsers == .loaded([.mock]))
    }
}

// MARK: - Mock Data

private extension BlockedUser {
    static let mock = BlockedUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        name: "차단된 유저",
        profileImageURL: nil,
        blockedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
