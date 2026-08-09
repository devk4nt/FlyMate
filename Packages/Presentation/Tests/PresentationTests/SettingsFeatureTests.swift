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
            $0.destination = .studyManagement(StudyManagementFeature.State())
        }
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
        }

        await store.send(.onAppear)
        await store.receive(\.pushStatusResponse) {
            $0.pushAuthorizationStatus = .denied
            $0.notificationsEnabled = false
        }
    }

    @Test
    func 진입시_권한_허용이면_토글_유지() async {
        let store = TestStore(initialState: SettingsFeature.State(currentUser: .settingsMock)) {
            SettingsFeature()
        } withDependencies: {
            $0.pushNotificationClient.getAuthorizationStatus = { .authorized }
        }

        await store.send(.onAppear)
        await store.receive(\.pushStatusResponse) {
            $0.pushAuthorizationStatus = .authorized
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
        TextState("모든 데이터가 삭제됩니다. 정말 탈퇴하시겠습니까?")
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
