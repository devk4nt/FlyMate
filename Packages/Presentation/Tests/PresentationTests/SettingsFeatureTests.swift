import Foundation
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
            $0.authClient.deleteAccount = {}
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
            $0.authClient.deleteAccount = { throw AppError.network(.serverError(statusCode: 500)) }
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
