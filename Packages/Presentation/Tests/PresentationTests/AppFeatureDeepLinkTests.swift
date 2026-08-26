import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct AppFeatureDeepLinkTests {
    private static let mockUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        email: "test@example.com",
        name: "테스트 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    private static let mockAnnouncement = AppNotification(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        recipientID: mockUser.id,
        type: .announcement,
        title: "서비스 공지",
        body: "새로운 공지 내용입니다.",
        referenceAnnouncementID: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    // MARK: - 시작 공지

    @Test
    func 앱_시작시_미노출_공지를_팝업으로_표시() async {
        let announcement = Self.mockAnnouncement
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.hasCheckedOnboarding = true
        state.destination = .tab(TabFeature.State(currentUser: Self.mockUser))

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.notificationClient.fetchStartupAnnouncement = { announcement }
        }

        await store.send(.startupAnnouncementRequested)
        await store.receive(\.startupAnnouncementResponse.success) {
            $0.announcement = AnnouncementDetailFeature.State(notification: announcement)
        }
    }

    // MARK: - Tab 상태에서 딥링크

    @Test
    func 탭_상태에서_초대코드_딥링크_전달() async {
        let tabState = TabFeature.State(currentUser: Self.mockUser)

        var state = AppFeature.State()
        state.destination = .tab(tabState)

        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.deepLink(.inviteCode("ABC123")))
        await store.receive(\.destination.tab.showInviteCode)
    }

    // MARK: - 로그인 상태에서 딥링크 → 보류

    @Test
    func 로그인_상태에서_딥링크_보류_저장() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.deepLink(.inviteCode("PEND01"))) {
            $0.pendingDeepLink = .inviteCode("PEND01")
        }
    }

    // MARK: - 로그인 성공 후 보류 딥링크 소비

    @Test
    func 로그인_후_보류_딥링크_자동_전달() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())
        state.pendingDeepLink = .inviteCode("PEND01")

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in .free }
            $0.subscriptionClient.observeTransactionUpdates = { .finished }
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.userDefaultsClient.boolForKey = { _ in true }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser)) {
            $0.currentUser = Self.mockUser
            $0.pendingDeepLink = nil
            $0.destination = .tab(TabFeature.State(currentUser: Self.mockUser))
        }

        await store.receive(\.deepLink)
    }

    // MARK: - 보류 딥링크 없이 로그인

    @Test
    func 보류_딥링크_없으면_로그인_후_추가_액션_없음() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.subscriptionClient.fetchEntitlements = { _ in .free }
            $0.subscriptionClient.observeTransactionUpdates = { .finished }
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.userDefaultsClient.boolForKey = { _ in true }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser)) {
            $0.currentUser = Self.mockUser
            $0.destination = .tab(TabFeature.State(currentUser: Self.mockUser))
        }
    }

    // MARK: - 로그아웃

    @Test
    func 로그아웃_완료시_로그인_화면_전환() async {
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.destination = .tab(TabFeature.State(currentUser: Self.mockUser))

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.destination(.tab(.settings(.signOutCompleted)))) {
            $0.currentUser = nil
            $0.destination = .login(LoginFeature.State())
        }
    }

    @Test
    func 회원탈퇴_완료시_로그인_화면_전환() async {
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.destination = .tab(TabFeature.State(currentUser: Self.mockUser))

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.destination(.tab(.settings(.deleteAccountCompleted)))) {
            $0.currentUser = nil
            $0.destination = .login(LoginFeature.State())
        }
    }

    // MARK: - 이용약관 동의 게이트

    @Test
    func 약관_미동의_상태로_로그인시_동의_화면_표시() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.userDefaultsClient.boolForKey = { _ in false }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser)) {
            $0.termsConsent = TermsConsentFeature.State()
        }

        await store.send(.termsConsent(.delegate(.consented))) {
            $0.termsConsent = nil
        }
    }

    // MARK: - 첫 실행 동선 (로그인 → 온보딩 → 가이드라인)

    @Test
    func 로그인_완료시_온보딩과_가이드라인_동의가_함께_준비() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.userDefaultsClient.boolForKey = { _ in false }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser)) {
            $0.destination = .tab(TabFeature.State(currentUser: Self.mockUser))
            $0.termsConsent = TermsConsentFeature.State()
        }

        await store.receive(\.checkOnboarding) {
            $0.hasCheckedOnboarding = true
            $0.didShowOnboardingThisSession = true
            $0.onboarding = OnboardingFeature.State()
        }
    }

    @Test
    func 온보딩에서_첫_업로드_선택시_업로드_화면으로_라우팅() async {
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.destination = .tab(TabFeature.State(currentUser: Self.mockUser))
        state.onboarding = OnboardingFeature.State()

        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.onboarding(.delegate(.firstUploadRequested))) {
            $0.onboarding = nil
        }

        await store.receive(\.destination.tab.study.startFirstVideoUpload)
    }

    @Test
    func 온보딩_본_세션에는_시작_공지_보류() {
        var state = AppFeature.State()
        state.currentUser = Self.mockUser
        state.hasCheckedOnboarding = true
        state.didShowOnboardingThisSession = true

        #expect(state.startupAnnouncementUserID == nil)

        state.didShowOnboardingThisSession = false
        #expect(state.startupAnnouncementUserID == Self.mockUser.id)
    }

    @Test
    func 약관_동의_완료_상태면_동의_화면_미표시() async {
        var state = AppFeature.State()
        state.destination = .login(LoginFeature.State())

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.pushNotificationClient.requestAuthorization = { false }
            $0.pushNotificationClient.registerForRemoteNotifications = {}
            $0.pushNotificationClient.observeFCMToken = { .finished }
            $0.userClient.fetchVerifiedUserIDs = { [] }
            $0.userDefaultsClient.boolForKey = { _ in true }
        }
        store.exhaustivity = .off

        await store.send(.authStateChanged(Self.mockUser))

        #expect(store.state.termsConsent == nil)
    }
}
