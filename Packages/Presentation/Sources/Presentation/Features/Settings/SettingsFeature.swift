import Foundation
import UIKit
import UserNotifications
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentUser: User
        public var notificationsEnabled = true
        public var pushAuthorizationStatus: UNAuthorizationStatus = .notDetermined
        @Presents public var destination: Destination.State?
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?

        public init(currentUser: User) {
            self.currentUser = currentUser
        }
    }

    public enum Action {
        case onAppear
        case pushStatusResponse(UNAuthorizationStatus)
        case profileEditTapped
        case studyManagementTapped
        case subscriptionTapped
        case notificationToggled(Bool)
        case signOutTapped
        case deleteAccountTapped
        case destination(PresentationAction<Destination.Action>)
        case confirmAlert(PresentationAction<ConfirmAlert>)
        case signOutCompleted
        case signOutFailed(AppError)
        case deleteAccountCompleted
        case deleteAccountFailed(AppError)

        public enum ConfirmAlert: Equatable {
            case confirmSignOut
            case confirmDeleteAccount
        }
    }

    @Reducer(state: .equatable)
    public enum Destination {
        case profileEdit(ProfileEditFeature)
        case studyManagement(StudyManagementFeature)
        case subscription(SubscriptionFeature)
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.appleSignInClient) private var appleSignInClient
    @Dependency(\.userClient) private var userClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.openURL) private var openURL

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let pushClient = pushNotificationClient
                return .run { send in
                    let status = await pushClient.getAuthorizationStatus()
                    await send(.pushStatusResponse(status))
                }

            case .pushStatusResponse(let status):
                state.pushAuthorizationStatus = status
                // ponytail: 서버 알림 설정은 쓰기 전용이라 OS 권한만 반영 — 거부 시에만 강제 off
                if status == .denied || status == .notDetermined {
                    state.notificationsEnabled = false
                }
                return .none

            case .profileEditTapped:
                state.destination = .profileEdit(
                    ProfileEditFeature.State(currentUser: state.currentUser)
                )
                return .none

            case .studyManagementTapped:
                state.destination = .studyManagement(StudyManagementFeature.State())
                return .none

            case .subscriptionTapped:
                state.destination = .subscription(
                    SubscriptionFeature.State(currentUserID: state.currentUser.id)
                )
                return .none

            case .notificationToggled(let enabled):
                if enabled {
                    switch state.pushAuthorizationStatus {
                    case .denied:
                        // 권한 거부 상태 — 시스템 설정으로 이동 (복귀 시 onAppear로 상태 재조회)
                        let open = openURL
                        return .run { _ in
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                await open(url)
                            }
                        }
                    case .notDetermined:
                        let pushClient = pushNotificationClient
                        return .run { send in
                            let granted = (try? await pushClient.requestAuthorization()) ?? false
                            await send(.pushStatusResponse(granted ? .authorized : .denied))
                            if granted {
                                await send(.notificationToggled(true))
                            }
                        }
                    default:
                        break
                    }
                }
                state.notificationsEnabled = enabled
                let client = userClient
                return .run { _ in
                    try await client.updateNotificationSettings(enabled)
                }

            case .signOutTapped:
                state.confirmAlert = AlertState {
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
                return .none

            case .deleteAccountTapped:
                state.confirmAlert = AlertState {
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
                return .none

            case .confirmAlert(.presented(.confirmSignOut)):
                let client = authClient
                return .run { send in
                    do {
                        try await client.signOut()
                        await send(.signOutCompleted)
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.signOutFailed(appError))
                    }
                }

            case .confirmAlert(.presented(.confirmDeleteAccount)):
                let client = authClient
                let appleClient = appleSignInClient
                let provider = state.currentUser.provider
                return .run { send in
                    do {
                        // Apple 계정은 재인증으로 authorization code를 받아 서버에서
                        // Sign in with Apple 토큰을 revoke한다 (App Store 심사 요구사항)
                        var appleCode: String?
                        if provider == .apple {
                            appleCode = try await appleClient.signIn().authorizationCode
                        }
                        try await client.deleteAccount(appleCode)
                        await send(.deleteAccountCompleted)
                    } catch AppleSignInError.canceled {
                        // 재인증 취소 = 탈퇴 취소
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.deleteAccountFailed(appError))
                    }
                }

            case .signOutCompleted, .deleteAccountCompleted,
                 .signOutFailed, .deleteAccountFailed:
                return .none

            case .destination(.presented(.profileEdit(.profileUpdated(let user)))):
                state.currentUser = user
                state.destination = nil
                return .none

            case .destination, .confirmAlert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmAlert, action: \.confirmAlert)
    }
}
