import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

/// GA4 User-ID 연동 — 설정하지 않으면 유지율이 사람이 아닌 기기 단위로 집계된다
@MainActor
struct AppFeatureAnalyticsTests {
    private static let mockUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        email: "test@example.com",
        name: "테스트 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    @Test
    func 로그인시_가명UUID로_UserID를_설정한다() async {
        let captured = LockIsolated<[String?]>([])
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.analyticsClient.setUserID = { id in captured.withValue { $0.append(id) } }
            $0.userDefaultsClient.boolForKey = { _ in true }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.notificationClient.fetchStartupAnnouncement = { nil }
            // 로그인 직후 푸시 권한 요청 흐름은 이 테스트의 관심사가 아니다
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser))

        #expect(captured.value == ["00000000-0000-0000-0000-000000000010"])
        // 이메일이 섞여 나가면 PII 유출 — 가명 UUID만 허용한다
        #expect(captured.value.compactMap(\.self).allSatisfy { !$0.contains("@") })
    }

    @Test
    func 로그아웃시_UserID를_해제한다() async {
        let captured = LockIsolated<[String?]>([])
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.destination = .tab(TabFeature.State(currentUser: Self.mockUser))

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.analyticsClient.setUserID = { id in captured.withValue { $0.append(id) } }
        }
        store.exhaustivity = .off

        await store.send(.destination(.tab(.settings(.signOutCompleted))))

        #expect(captured.value == [nil])
    }
}
