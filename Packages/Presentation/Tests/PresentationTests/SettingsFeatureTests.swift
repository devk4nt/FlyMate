import Foundation
import UIKit
import UserNotifications
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct SettingsFeatureTests {
    @Test
    func 프로필_편집_화면_표시() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        }

        await store.send(.profileEditTapped) {
            $0.destination = .profileEdit(ProfileEditFeature.State(currentUser: .settingsMock))
        }
    }

    @Test
    func 구독_화면_표시() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        }

        await store.send(.subscriptionTapped) {
            $0.destination = .subscription(
                SubscriptionFeature.State(currentUserID: User.settingsMock.id)
            )
        }
    }

    @Test
    func 스터디_관리_화면_표시() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        }

        await store.send(.studyManagementTapped) {
            $0.isStudyManagementActive = true
        }
    }

    @Test
    func 개발자에게_문의하기_메일_열기() async {
        let openedURL = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                openedURL.setValue(url)
                return true
            }
        }

        await store.send(.developerContactTapped)
        await store.receive(\.developerContactOpenResponse, true)

        let components = openedURL.value.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }
        #expect(openedURL.value?.scheme == "mailto")
        #expect(openedURL.value?.path == AppConstants.supportEmail)
        #expect(components?.queryItems?.contains(where: { $0.name == "subject" }) == true)
        #expect(components?.queryItems?.contains(where: {
            $0.name == "body" && $0.value?.contains(User.settingsMock.id.uuidString) == true
        }) == true)
    }

    @Test
    func 메일_앱을_열_수_없으면_안내_표시() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { _ in false }
        }

        await store.send(.developerContactTapped)
        await store.receive(\.developerContactOpenResponse, false) {
            $0.confirmAlert = Self.mailUnavailableAlert
        }
    }

    @Test
    func 버그_신고_메일에_상세내용과_진단정보_포함() {
        let draft = BugReportDraft(
            screenshotData: nil,
            userID: "test-user-id",
            account: "tester@example.com",
            appVersion: "1.0.0 (1)",
            deviceDescription: "iPhone · iOS 17.0"
        )

        let body = draft.mailBody(detail: "저장 버튼을 누르면 화면이 멈춰요.")

        #expect(body.contains("저장 버튼을 누르면 화면이 멈춰요."))
        #expect(body.contains("앱 버전: 1.0.0 (1)"))
        #expect(body.contains("회원 ID: test-user-id"))
        #expect(body.contains("계정: tester@example.com"))
    }

    @Test
    func 버그_신고_대체_메일_URL_생성() {
        let mailDraft = BugReportMailDraft(
            recipient: AppConstants.supportEmail,
            subject: "[FlyMate 버그 신고] 1.0.0",
            body: "버그 신고 내용",
            screenshotData: nil
        )

        let components = mailDraft.mailtoURL.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)
        }

        #expect(mailDraft.mailtoURL?.scheme == "mailto")
        #expect(mailDraft.mailtoURL?.path == AppConstants.supportEmail)
        #expect(components?.queryItems?.first(where: { $0.name == "subject" })?.value == "[FlyMate 버그 신고] 1.0.0")
        #expect(components?.queryItems?.first(where: { $0.name == "body" })?.value == "버그 신고 내용")
    }

    @Test
    func 알림_설정_끄기() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.userClient.updateNotificationSettings = { _ in }
        }

        await store.send(.notificationToggled(false)) {
            $0.notificationsEnabled = false
        }
    }

    @Test
    func 진입시_권한_거부면_토글_꺼짐() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.pushNotificationClient.getAuthorizationStatus = { .denied }
            $0.cacheClient.diskCacheSize = { 1_024 }
        }

        await store.send(.onAppear) {
            $0.cacheSize = .loading
        }
        await store.receive(\.pushStatusResponse) {
            $0.pushAuthorizationStatus = .denied
            $0.notificationsEnabled = false
        }
        await store.receive(\.cacheSizeResponse.success) {
            $0.cacheSize = .loaded(1_024)
        }
    }

    @Test
    func 진입시_권한_허용이면_토글_유지() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.pushNotificationClient.getAuthorizationStatus = { .authorized }
            $0.cacheClient.diskCacheSize = { 1_024 }
        }

        await store.send(.onAppear) {
            $0.cacheSize = .loading
        }
        await store.receive(\.pushStatusResponse) {
            $0.pushAuthorizationStatus = .authorized
        }
        await store.receive(\.cacheSizeResponse.success) {
            $0.cacheSize = .loaded(1_024)
        }
    }

    @Test
    func 권한_거부_상태에서_토글_켜면_시스템_설정_이동() async {
        let openedURL = LockIsolated<URL?>(nil)
        var state = SettingsFeature.State(currentUser: .settingsMock)
        state.pushAuthorizationStatus = .denied
        state.notificationsEnabled = false

        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.openURL = OpenURLEffect { url in
                openedURL.setValue(url)
                return true
            }
        }

        await store.send(.notificationToggled(true))
        #expect(openedURL.value?.absoluteString == UIApplication.openSettingsURLString)
    }

    @Test
    func 권한_미결정_상태에서_토글_켜면_권한_요청_후_켜짐() async {
        var state = SettingsFeature.State(currentUser: .settingsMock)
        state.notificationsEnabled = false

        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.pushNotificationClient.requestAuthorization = { true }
            $0.userClient.updateNotificationSettings = { _ in }
        }

        await store.send(.notificationToggled(true))
        await store.receive(\.pushStatusResponse) {
            $0.pushAuthorizationStatus = .authorized
        }
        await store.receive(\.notificationToggled) {
            $0.notificationsEnabled = true
        }
    }

    @Test
    func 로그아웃_확인_후_성공() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.authClient.signOut = {}
        }

        await store.send(.signOutTapped) {
            $0.confirmAlert = Self.signOutAlert
        }

        await store.send(.confirmAlert(.presented(.confirmSignOut))) {
            $0.confirmAlert = nil
        }

        await store.receive(\.signOutCompleted)
    }

    @Test
    func 로그아웃_실패() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.authClient.signOut = { throw AppError.network(.noConnection) }
        }

        await store.send(.signOutTapped) {
            $0.confirmAlert = Self.signOutAlert
        }

        await store.send(.confirmAlert(.presented(.confirmSignOut))) {
            $0.confirmAlert = nil
        }

        await store.receive(\.signOutFailed)
    }

    @Test
    func 계정_삭제_확인_후_성공() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.appleSignInClient.signIn = { Self.reAuthResult }
            $0.authClient.deleteAccount = { code in
                #expect(code == "mock-auth-code")
            }
        }

        await store.send(.deleteAccountTapped) {
            $0.confirmAlert = Self.deleteAccountAlert
        }

        await store.send(.confirmAlert(.presented(.confirmDeleteAccount))) {
            $0.confirmAlert = nil
        }

        await store.receive(\.deleteAccountCompleted)
    }

    @Test
    func 계정_삭제_실패() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.appleSignInClient.signIn = { Self.reAuthResult }
            $0.authClient.deleteAccount = { _ in throw AppError.network(.serverError(statusCode: 500)) }
        }

        await store.send(.deleteAccountTapped) {
            $0.confirmAlert = Self.deleteAccountAlert
        }

        await store.send(.confirmAlert(.presented(.confirmDeleteAccount))) {
            $0.confirmAlert = nil
        }

        await store.receive(\.deleteAccountFailed)
    }

    @Test
    func Apple_재인증_취소시_탈퇴_중단() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.appleSignInClient.signIn = { throw AppleSignInError.canceled }
        }

        await store.send(.deleteAccountTapped) {
            $0.confirmAlert = Self.deleteAccountAlert
        }

        // 재인증 취소 시 deleteAccount 호출 없이 종료 (deleteAccount는 unimplemented)
        await store.send(.confirmAlert(.presented(.confirmDeleteAccount))) {
            $0.confirmAlert = nil
        }
    }

    @Test
    func 프로필_수정_완료시_현재_유저_갱신_및_화면_닫힘() async {
        var state = SettingsFeature.State(currentUser: .settingsMock)
        state.destination = .profileEdit(ProfileEditFeature.State(currentUser: .settingsMock))

        let store = TestStore(initialState: state) {
            SettingsFeature()
        }

        await store.send(.destination(.presented(.profileEdit(.profileUpdated(.settingsUpdatedMock))))) {
            $0.currentUser = .settingsUpdatedMock
            $0.destination = nil
        }
    }

    // MARK: - Mock Apple Re-auth

    private nonisolated static let reAuthResult = AppleSignInResult(
        idToken: "mock-id-token",
        nonce: "mock-nonce",
        fullName: nil,
        email: nil,
        authorizationCode: "mock-auth-code"
    )

    // MARK: - Alert States

    private static let signOutAlert = AlertState<SettingsFeature.Action.ConfirmAlert> {
        TextState("로그아웃")
    } actions: {
        ButtonState(role: .destructive, action: .confirmSignOut) {
            TextState("로그아웃")
        }
        ButtonState(role: .cancel) {
            TextState("취소")
        }
    } message: {
        TextState("정말 로그아웃하시겠습니까?")
    }

    private static let deleteAccountAlert = AlertState<SettingsFeature.Action.ConfirmAlert> {
        TextState("회원 탈퇴")
    } actions: {
        ButtonState(role: .destructive, action: .confirmDeleteAccount) {
            TextState("탈퇴하기")
        }
        ButtonState(role: .cancel) {
            TextState("취소")
        }
    } message: {
        TextState("모든 데이터가 삭제됩니다. 방장인 스터디는 가장 오래된 멤버에게 방장이 자동으로 위임됩니다. 정말 탈퇴하시겠습니까?")
    }

    private static let mailUnavailableAlert = AlertState<SettingsFeature.Action.ConfirmAlert> {
        TextState("메일 앱을 열 수 없어요")
    } actions: {
        ButtonState(role: .cancel) {
            TextState("확인")
        }
    } message: {
        TextState("메일 앱을 설정한 뒤 다시 시도해 주세요. 문의 주소는 \(AppConstants.supportEmail)입니다.")
    }
}

// MARK: - Mock Data

private extension User {
    static let settingsMock = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        email: "settings@example.com",
        name: "설정 테스트 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    static let settingsUpdatedMock = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        email: "settings@example.com",
        name: "수정된 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
