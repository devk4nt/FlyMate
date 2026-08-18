import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct AppFeature : Sendable {
    #if DEBUG
    /// 디버그 기본값은 목 데이터 자동 진입. LIVE_AUTH=1이면 실제 로그인 플로우 (FlyMate-Live 스킴)
    public static let skipAuth = ProcessInfo.processInfo.environment["LIVE_AUTH"] != "1"
    #endif

    @ObservableState
    public struct State: Equatable {
        public var currentUser: User?
        public var destination: Destination
        public var toast: ToastState?
        public var pendingDeepLink: DeepLink?
        public var fcmToken: String?
        public var entitlement: Entitlement?
        public var onboarding: OnboardingFeature.State?
        public var termsConsent: TermsConsentFeature.State?
        public var hasCheckedOnboarding = false
        @Presents public var announcement: AnnouncementDetailFeature.State?

        public var startupAnnouncementUserID: UUID? {
            guard hasCheckedOnboarding, onboarding == nil, termsConsent == nil else { return nil }
            return currentUser?.id
        }

        public init() {
            self.destination = .login(LoginFeature.State())
        }

        public enum Destination: Equatable {
            case login(LoginFeature.State)
            case tab(TabFeature.State)
        }
    }

    public enum Action {
        case onAppear
        case authStateChanged(User?)
        case destination(Destination)
        case deepLink(DeepLink)
        case toastDismissed
        case requestPushPermission
        case pushPermissionResponse(Bool)
        case fcmTokenReceived(String)
        case registerTokenResponse
        case pushNotificationTapped([String: String])
        case checkOnboarding
        case onboarding(OnboardingFeature.Action)
        case termsConsent(TermsConsentFeature.Action)
        case entitlementLoaded(Entitlement)
        case transactionUpdated
        case startupAnnouncementRequested
        case startupAnnouncementResponse(Result<AppNotification?, AppError>)
        case startupAnnouncementMarkedAsRead
        case announcement(PresentationAction<AnnouncementDetailFeature.Action>)

        @CasePathable
        public enum Destination {
            case login(LoginFeature.Action)
            case tab(TabFeature.Action)
        }
    }

    private enum CancelID {
        case fcmTokenObserver
        case pushNotificationObserver
        case transactionUpdates
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.userClient) private var userClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient
    @Dependency(\.subscriptionClient) private var subscriptionClient
    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.notificationClient) private var notificationClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let client = authClient
                return .merge(
                    .run { send in
                        // 디버그 자동 로그인 (Supabase 세션 확보)
                        if let debugSignIn = client.debugSignIn {
                            do {
                                try await debugSignIn()
                                print("🟢 [Auth] debugSignIn 성공")
                            } catch {
                                print("🔴 [Auth] debugSignIn 실패: \(error)")
                            }
                        }

                        // 현재 인증 상태 확인
                        let user = try? await client.currentUser()
                        await send(.authStateChanged(user))

                        // 인증 상태 변경 구독
                        for await user in client.observeAuthState() {
                            await send(.authStateChanged(user))
                        }
                    },
                    // 푸시 알림 탭 구독
                    .run { send in
                        let pushClient = pushNotificationClient
                        for await payload in pushClient.observePushNotificationTapped() {
                            await send(.pushNotificationTapped(payload))
                        }
                    }
                    .cancellable(id: CancelID.pushNotificationObserver),
                    .send(.checkOnboarding)
                )

            case .checkOnboarding:
                state.hasCheckedOnboarding = true
                let hasCompleted = userDefaultsClient.boolForKey("hasCompletedOnboarding")
                if !hasCompleted {
                    state.onboarding = OnboardingFeature.State()
                }
                return .none

            case .onboarding(.delegate(.onboardingCompleted)):
                state.onboarding = nil
                return .none

            case .onboarding:
                return .none

            case .termsConsent(.delegate(.consented)):
                state.termsConsent = nil
                return .send(.requestPushPermission)

            case .termsConsent:
                return .none

            case .authStateChanged(let user):
                state.currentUser = user
                if let user {
                    if case .login = state.destination {
                        state.destination = .tab(TabFeature.State(currentUser: user))
                        // UGC 이용 전 커뮤니티 가이드라인 동의 필수 (Guideline 1.2)
                        if !userDefaultsClient.boolForKey(TermsConsentFeature.consentKey) {
                            state.termsConsent = TermsConsentFeature.State()
                        }
                        var effects: [Effect<Action>] = [
                            // 동의 시트가 떠 있으면 시스템 팝업 중첩 방지 — 동의 완료 후 요청
                            state.termsConsent == nil ? .send(.requestPushPermission) : .none,
                            // ponytail: 구독 미출시 — entitlement 조회 + Transaction.updates 구독 비활성.
                            // verify-receipt/app-store-webhook 배포 후 아래 주석 복원 (SettingsView 구독 버튼과 함께)
                            // .run { [subClient = subscriptionClient, userID = user.id] send in
                            //     let entitlement = try? await subClient.fetchEntitlements(userID)
                            //     if let entitlement {
                            //         await send(.entitlementLoaded(entitlement))
                            //     }
                            // },
                            // .run { [subClient = subscriptionClient] send in
                            //     for await _ in subClient.observeTransactionUpdates() {
                            //         await send(.transactionUpdated)
                            //     }
                            // }
                            // .cancellable(id: CancelID.transactionUpdates)
                        ]
                        if let pendingDeepLink = state.pendingDeepLink {
                            state.pendingDeepLink = nil
                            effects.append(.send(.deepLink(pendingDeepLink)))
                        }
                        return .merge(effects)
                    }
                } else {
                    // 로그아웃 시 FCM 토큰 제거 + 구독 상태 초기화
                    let fcmToken = state.fcmToken
                    state.fcmToken = nil
                    state.entitlement = nil
                    state.destination = .login(LoginFeature.State())
                    return .merge(
                        .cancel(id: CancelID.fcmTokenObserver),
                        .cancel(id: CancelID.transactionUpdates),
                        fcmToken.map { token in
                            let client = userClient
                            return Effect<Action>.run { _ in
                                try? await client.removeDeviceToken(token)
                            }
                        } ?? .none
                    )
                }
                return .none

            case .requestPushPermission:
                let pushClient = pushNotificationClient
                return .run { send in
                    let granted = try await pushClient.requestAuthorization()
                    await send(.pushPermissionResponse(granted))
                } catch: { _, send in
                    await send(.pushPermissionResponse(false))
                }

            case .pushPermissionResponse(let granted):
                guard granted else { return .none }
                let pushClient = pushNotificationClient
                return .run { send in
                    await pushClient.registerForRemoteNotifications()
                    for await token in pushClient.observeFCMToken() {
                        await send(.fcmTokenReceived(token))
                    }
                }
                .cancellable(id: CancelID.fcmTokenObserver)

            case .fcmTokenReceived(let token):
                state.fcmToken = token
                let client = userClient
                return .run { _ in
                    try await client.registerDeviceToken(token)
                } catch: { error, _ in
                    print("🔴 [Push] Failed to register FCM token: \(error)")
                }

            case .registerTokenResponse:
                return .none

            case .pushNotificationTapped(let payload):
                guard let videoIDString = payload["videoId"],
                      let videoID = UUID(uuidString: videoIDString) else {
                    return .none
                }
                let feedbackID = payload["feedbackId"].flatMap(UUID.init(uuidString:))
                return .send(.deepLink(.videoDetail(studyID: UUID(), videoID: videoID, feedbackID: feedbackID)))

            case .deepLink(let deepLink):
                switch deepLink {
                case .inviteCode(let code):
                    if case .tab = state.destination {
                        return .send(.destination(.tab(.showInviteCode(code))))
                    } else {
                        state.pendingDeepLink = deepLink
                    }
                case .videoDetail(_, let videoID, let feedbackID):
                    if case .tab = state.destination {
                        return .send(.destination(.tab(.navigateToVideoByID(videoID, feedbackID: feedbackID))))
                    } else {
                        state.pendingDeepLink = deepLink
                    }
                }
                return .none

            case .toastDismissed:
                state.toast = nil
                return .none

            case .entitlementLoaded(let entitlement):
                state.entitlement = entitlement
                return .none

            case .transactionUpdated:
                guard let userID = state.currentUser?.id else { return .none }
                let subClient = subscriptionClient
                return .run { send in
                    let entitlement = try? await subClient.fetchEntitlements(userID)
                    if let entitlement {
                        await send(.entitlementLoaded(entitlement))
                    }
                }

            case .startupAnnouncementRequested:
                guard state.startupAnnouncementUserID != nil,
                      state.announcement == nil else { return .none }
                let client = notificationClient
                return .run { send in
                    do {
                        let announcement = try await client.fetchStartupAnnouncement()
                        await send(.startupAnnouncementResponse(.success(announcement)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.startupAnnouncementResponse(.failure(appError)))
                    }
                }

            case .startupAnnouncementResponse(.success(let notification)):
                state.announcement = notification.map(AnnouncementDetailFeature.State.init)
                return .none

            case .startupAnnouncementResponse(.failure):
                return .none

            case .announcement(.presented(.closeTapped)):
                guard let notificationID = state.announcement?.notification.id else {
                    return .none
                }
                state.announcement = nil
                let client = notificationClient
                return .run { send in
                    try? await client.markAsRead(notificationID)
                    await send(.startupAnnouncementMarkedAsRead)
                }

            case .startupAnnouncementMarkedAsRead:
                guard case .tab = state.destination else { return .none }
                return .send(.destination(.tab(.refreshUnreadCount)))

            case .announcement:
                return .none

            case .destination(.tab(.settings(.signOutCompleted))),
                 .destination(.tab(.settings(.deleteAccountCompleted))):
                let fcmToken = state.fcmToken
                state.currentUser = nil
                state.fcmToken = nil
                state.entitlement = nil
                state.destination = .login(LoginFeature.State())
                return .merge(
                    .cancel(id: CancelID.fcmTokenObserver),
                    .cancel(id: CancelID.transactionUpdates),
                    fcmToken.map { token in
                        let client = userClient
                        return Effect<Action>.run { _ in
                            try? await client.removeDeviceToken(token)
                        }
                    } ?? .none
                )

            case .destination:
                return .none
            }
        }
        .ifLet(\.loginState, action: \.destination.login) {
            LoginFeature()
        }
        .ifLet(\.$announcement, action: \.announcement) {
            AnnouncementDetailFeature()
        }
        .ifLet(\.tabState, action: \.destination.tab) {
            TabFeature()
        }
        .ifLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifLet(\.termsConsent, action: \.termsConsent) {
            TermsConsentFeature()
        }
    }
}

// MARK: - Computed State Accessors

extension AppFeature.State {
    var loginState: LoginFeature.State? {
        get {
            if case .login(let state) = destination { return state }
            return nil
        }
        set {
            if let newValue { destination = .login(newValue) }
        }
    }

    var tabState: TabFeature.State? {
        get {
            if case .tab(let state) = destination { return state }
            return nil
        }
        set {
            if let newValue { destination = .tab(newValue) }
        }
    }
}

// MARK: - Supporting Types

public enum DeepLink: Equatable {
    case inviteCode(String)
    case videoDetail(studyID: UUID, videoID: UUID, feedbackID: UUID? = nil)
}

public enum DeepLinkParser {
    /// Parses `flymate://invite?code=ABC123` format URLs
    public static func parse(url: URL) -> DeepLink? {
        guard url.scheme == "flymate" else { return nil }

        switch url.host {
        case "invite":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                  !code.isEmpty else {
                return nil
            }
            return .inviteCode(code)
        default:
            return nil
        }
    }
}

public struct ToastState: Equatable {
    public let message: String
    public let type: ToastType

    public enum ToastType: Equatable {
        case success
        case error
        case info
    }
}
