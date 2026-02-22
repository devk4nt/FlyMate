import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var currentUser: User
        public var notificationsEnabled = true
        @Presents public var destination: Destination.State?
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?

        public init(currentUser: User) {
            self.currentUser = currentUser
        }
    }

    public enum Action {
        case profileEditTapped
        case studyManagementTapped
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
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.userClient) private var userClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .profileEditTapped:
                state.destination = .profileEdit(
                    ProfileEditFeature.State(currentUser: state.currentUser)
                )
                return .none

            case .studyManagementTapped:
                state.destination = .studyManagement(StudyManagementFeature.State())
                return .none

            case .notificationToggled(let enabled):
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
                return .run { send in
                    do {
                        try await client.deleteAccount()
                        await send(.deleteAccountCompleted)
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
