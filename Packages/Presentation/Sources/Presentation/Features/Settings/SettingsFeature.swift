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
        public var smileReminderEnabled = false
        /// 1일 1미소 알림 시간 — 자정 기준 분
        public var smileReminderMinutes = AppConstants.PracticeMirror.reminderDefaultMinutes
        // 재진입 시 목록이 즉시 보이도록 자식 상태를 상주시킨다 (탭 루트 리스트와 동일한 전략)
        public var studyManagement: StudyManagementFeature.State
        public var blockedUsers = BlockedUsersFeature.State()
        public var isStudyManagementActive = false
        public var isBlockedUsersActive = false
        public var cacheSize: LoadingState<UInt> = .idle
        @Presents public var destination: Destination.State?
        @Presents public var confirmAlert: AlertState<Action.ConfirmAlert>?

        public init(currentUser: User) {
            self.currentUser = currentUser
            self.studyManagement = StudyManagementFeature.State(currentUserID: currentUser.id)
        }
    }

    public enum Action {
        case onAppear
        case pushStatusResponse(UNAuthorizationStatus)
        case profileEditTapped
        case myActivityTapped
        case studyManagementTapped
        case blockedUsersTapped
        case studyManagementActiveChanged(Bool)
        case blockedUsersActiveChanged(Bool)
        case studyManagement(StudyManagementFeature.Action)
        case blockedUsers(BlockedUsersFeature.Action)
        case developerContactTapped
        case rateAppTapped
        case developerContactOpenResponse(Bool)
        case verificationRequestTapped
        case notificationToggled(Bool)
        case smileReminderToggled(Bool)
        case smileReminderTimeChanged(Date)
        case signOutTapped
        case deleteAccountTapped
        case destination(PresentationAction<Destination.Action>)
        case confirmAlert(PresentationAction<ConfirmAlert>)
        case signOutCompleted
        case signOutFailed(AppError)
        case deleteAccountCompleted
        case deleteAccountFailed(AppError)
        case cacheSizeResponse(Result<UInt, AppError>)
        case clearCacheTapped
        case clearCacheCompleted

        public enum ConfirmAlert: Equatable {
            case confirmSignOut
            case confirmDeleteAccount
        }
    }

    @Reducer(state: .equatable)
    public enum Destination {
        case profileEdit(ProfileEditFeature)
        case myActivity(MyActivityFeature)
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.appleSignInClient) private var appleSignInClient
    @Dependency(\.userClient) private var userClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.cacheClient) private var cacheClient
    @Dependency(\.openURL) private var openURL
    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.smileReminderClient) private var smileReminderClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.studyManagement, action: \.studyManagement) {
            StudyManagementFeature()
        }
        Scope(state: \.blockedUsers, action: \.blockedUsers) {
            BlockedUsersFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.cacheSize = .loading
                state.smileReminderEnabled = userDefaultsClient.boolForKey(AppConstants.PracticeMirror.UserDefaultsKey.reminderEnabled)
                let storedMinutes = userDefaultsClient.integerForKey(AppConstants.PracticeMirror.UserDefaultsKey.reminderMinutesPlusOne)
                if storedMinutes > 0 {
                    state.smileReminderMinutes = storedMinutes - 1
                }
                let pushClient = pushNotificationClient
                return .merge(
                    .run { send in
                        let status = await pushClient.getAuthorizationStatus()
                        await send(.pushStatusResponse(status))
                    },
                    fetchCacheSize()
                )

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

            case .myActivityTapped:
                state.destination = .myActivity(
                    MyActivityFeature.State(currentUser: state.currentUser)
                )
                return .none

            case .studyManagementTapped:
                state.isStudyManagementActive = true
                return .none

            case .blockedUsersTapped:
                state.isBlockedUsersActive = true
                return .none

            case .studyManagementActiveChanged(let isActive):
                state.isStudyManagementActive = isActive
                return .none

            case .blockedUsersActiveChanged(let isActive):
                state.isBlockedUsersActive = isActive
                return .none

            case .studyManagement, .blockedUsers:
                return .none

            case .rateAppTapped:
                guard let url = URL(string: AppConstants.ServiceURL.appStore + "?action=write-review") else {
                    return .none
                }
                let open = openURL
                return .run { _ in
                    await open(url)
                }

            case .developerContactTapped:
                guard let url = Self.developerContactURL(for: state.currentUser) else {
                    return .send(.developerContactOpenResponse(false))
                }
                let open = openURL
                return .run { send in
                    await send(.developerContactOpenResponse(await open(url)))
                }

            case .verificationRequestTapped:
                guard let url = Self.verificationRequestURL(for: state.currentUser) else {
                    return .send(.developerContactOpenResponse(false))
                }
                let open = openURL
                return .run { send in
                    await send(.developerContactOpenResponse(await open(url)))
                }

            case .developerContactOpenResponse(true):
                return .none

            case .developerContactOpenResponse(false):
                state.confirmAlert = AlertState {
                    TextState("메일 앱을 열 수 없어요")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("메일 앱을 설정한 뒤 다시 시도해 주세요. 문의 주소는 \(AppConstants.supportEmail)입니다.")
                }
                return .none

            case .smileReminderToggled(let enabled):
                state.smileReminderEnabled = enabled
                let defaults = userDefaultsClient
                let reminder = smileReminderClient
                let pushClient = pushNotificationClient
                let minutes = state.smileReminderMinutes
                if enabled {
                    return .run { send in
                        // 시스템 알림 권한이 없으면 예약해도 전달되지 않는다 — 미허용 시 요청
                        let status = await pushClient.getAuthorizationStatus()
                        if status == .notDetermined {
                            let granted = (try? await pushClient.requestAuthorization()) ?? false
                            guard granted else {
                                await send(.smileReminderToggled(false))
                                return
                            }
                        } else if status == .denied {
                            await send(.smileReminderToggled(false))
                            return
                        }
                        await defaults.setBool(true, AppConstants.PracticeMirror.UserDefaultsKey.reminderEnabled)
                        await defaults.setInteger(minutes + 1, AppConstants.PracticeMirror.UserDefaultsKey.reminderMinutesPlusOne)
                        let recent = defaults.integerForKey(AppConstants.PracticeMirror.UserDefaultsKey.recentSmileRatioPercentPlusOne)
                        await reminder.reschedule(minutes, recent > 0 ? recent - 1 : nil)
                    }
                }
                return .run { _ in
                    await defaults.setBool(false, AppConstants.PracticeMirror.UserDefaultsKey.reminderEnabled)
                    await reminder.cancelAll()
                }

            case .smileReminderTimeChanged(let date):
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                state.smileReminderMinutes = minutes
                let isEnabled = state.smileReminderEnabled
                let defaults = userDefaultsClient
                let reminder = smileReminderClient
                return .run { _ in
                    await defaults.setInteger(minutes + 1, AppConstants.PracticeMirror.UserDefaultsKey.reminderMinutesPlusOne)
                    guard isEnabled else { return }
                    let recent = defaults.integerForKey(AppConstants.PracticeMirror.UserDefaultsKey.recentSmileRatioPercentPlusOne)
                    await reminder.reschedule(minutes, recent > 0 ? recent - 1 : nil)
                }

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
                    TextState("모든 데이터가 삭제됩니다. 방장인 스터디는 가장 오래된 멤버에게 방장이 자동으로 위임됩니다. 정말 탈퇴하시겠습니까?")
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

            case .cacheSizeResponse(.success(let bytes)):
                state.cacheSize = .loaded(bytes)
                return .none

            case .cacheSizeResponse(.failure(let error)):
                state.cacheSize = .failed(error)
                return .none

            case .clearCacheTapped:
                guard case .loaded = state.cacheSize else { return .none }
                state.cacheSize = .loading
                let cache = cacheClient
                return .run { send in
                    await cache.clearCache()
                    await send(.clearCacheCompleted)
                }

            case .clearCacheCompleted:
                return fetchCacheSize()
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmAlert, action: \.confirmAlert)
    }

    private static func developerContactURL(for user: User) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConstants.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[FlyMate 문의] 문의 유형을 입력해 주세요"),
            URLQueryItem(
                name: "body",
                value: """
                안녕하세요. FlyMate 이용 중 문의드려요.

                문의 내용:


                --------------------
                아래 정보는 문의 확인을 위해 자동으로 입력되었어요.
                회원 ID: \(user.id.uuidString)
                계정: \(user.displayEmail)
                """
            ),
        ]
        return components.url
    }

    private static func verificationRequestURL(for user: User) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConstants.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[FlyMate 현직자 인증] 인증 신청"),
            URLQueryItem(
                name: "body",
                value: """
                안녕하세요. FlyMate 현직자 인증을 신청합니다.

                ■ 아래 두 가지를 첨부해 주세요
                1. 본인 아이디를 손으로 적은 종이와 함께 촬영한 신분증 사진
                2. 재직증명서 또는 최종합격증명서

                확인 후 프로필에 현직자 뱃지를 달아드려요.

                --------------------
                아래 정보는 인증 확인을 위해 자동으로 입력되었어요.
                회원 ID: \(user.id.uuidString)
                계정: \(user.displayEmail)
                직군(승무원/아나운서 등):
                """
            ),
        ]
        return components.url
    }

    private func fetchCacheSize() -> Effect<Action> {
        let cache = cacheClient
        return .run { send in
            do {
                let bytes = try await cache.diskCacheSize()
                await send(.cacheSizeResponse(.success(bytes)))
            } catch {
                let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                await send(.cacheSizeResponse(.failure(appError)))
            }
        }
    }
}
