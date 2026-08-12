import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

private let testUser = User(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    email: "test@flymate.app",
    name: "테스터",
    provider: .apple,
    createdAt: Date(timeIntervalSince1970: 0)
)

private let testStats = MyActivityStats(
    studiesCount: 2,
    videosUploadedCount: 5,
    feedbackReceivedCount: 12,
    feedbackGivenCount: 9
)

@MainActor
struct MyActivityFeatureTests {
    @Test
    func 진입시_활동통계_로드성공() async {
        let store = TestStore(initialState: MyActivityFeature.State(currentUser: testUser)) {
            MyActivityFeature()
        } withDependencies: {
            $0.userClient.fetchMyActivityStats = { testStats }
        }

        await store.send(.onAppear) {
            $0.stats = .loading
        }

        await store.receive(\.statsResponse.success) {
            $0.stats = .loaded(testStats)
        }
    }

    @Test
    func 로드실패후_재시도() async {
        let store = TestStore(initialState: MyActivityFeature.State(currentUser: testUser)) {
            MyActivityFeature()
        } withDependencies: {
            $0.userClient.fetchMyActivityStats = { throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear) {
            $0.stats = .loading
        }

        await store.receive(\.statsResponse.failure) {
            $0.stats = .failed(.network(.noConnection))
        }

        store.dependencies.userClient.fetchMyActivityStats = { testStats }

        await store.send(.retry) {
            $0.stats = .idle
        }

        await store.receive(\.onAppear) {
            $0.stats = .loading
        }

        await store.receive(\.statsResponse.success) {
            $0.stats = .loaded(testStats)
        }
    }
}
