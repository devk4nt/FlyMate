import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct AppFeature : Sendable {
    #if DEBUG
    public static let skipAuth = true
    #endif

    @ObservableState
    public struct State: Equatable {
        public var currentUser: User?
        public var destination: Destination
        public var toast: ToastState?
        public var pendingDeepLink: DeepLink?
        public var fcmToken: String?

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

        @CasePathable
        public enum Destination {
            case login(LoginFeature.Action)
            case tab(TabFeature.Action)
        }
    }

    private enum CancelID {
        case fcmTokenObserver
        case pushNotificationObserver
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.userClient) private var userClient
    @Dependency(\.pushNotificationClient) private var pushNotificationClient

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
                    .cancellable(id: CancelID.pushNotificationObserver)
                )

            case .authStateChanged(let user):
                state.currentUser = user
                if let user {
                    if case .login = state.destination {
                        state.destination = .tab(TabFeature.State(currentUser: user))
                        var effects: [Effect<Action>] = [.send(.requestPushPermission)]
                        if let pendingDeepLink = state.pendingDeepLink {
                            state.pendingDeepLink = nil
                            effects.append(.send(.deepLink(pendingDeepLink)))
                        }
                        return .merge(effects)
                    }
                } else {
                    // 로그아웃 시 FCM 토큰 제거
                    let fcmToken = state.fcmToken
                    state.fcmToken = nil
                    state.destination = .login(LoginFeature.State())
                    return .merge(
                        .cancel(id: CancelID.fcmTokenObserver),
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
                return .send(.deepLink(.videoDetail(studyID: UUID(), videoID: videoID)))

            case .deepLink(let deepLink):
                switch deepLink {
                case .inviteCode(let code):
                    if case .tab = state.destination {
                        return .send(.destination(.tab(.showInviteCode(code))))
                    } else {
                        state.pendingDeepLink = deepLink
                    }
                case .videoDetail(_, let videoID):
                    if case .tab = state.destination {
                        return .send(.destination(.tab(.navigateToVideoByID(videoID))))
                    } else {
                        state.pendingDeepLink = deepLink
                    }
                }
                return .none

            case .toastDismissed:
                state.toast = nil
                return .none

            case .destination(.tab(.settings(.signOutCompleted))),
                 .destination(.tab(.settings(.deleteAccountCompleted))):
                let fcmToken = state.fcmToken
                state.currentUser = nil
                state.fcmToken = nil
                state.destination = .login(LoginFeature.State())
                return .merge(
                    .cancel(id: CancelID.fcmTokenObserver),
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
        .ifLet(\.tabState, action: \.destination.tab) {
            TabFeature()
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
    case videoDetail(studyID: UUID, videoID: UUID)
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
