import Foundation
import ComposableArchitecture
import Domain

@Reducer
public struct AppFeature {
    #if DEBUG
    public static let skipAuth = true
    #endif

    @ObservableState
    public struct State: Equatable {
        public var currentUser: User?
        public var destination: Destination
        public var toast: ToastState?
        public var pendingDeepLink: DeepLink?

        public init() {
            #if DEBUG
            if AppFeature.skipAuth {
                let previewUser = User(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                    email: "preview@flymate.app",
                    name: "Preview User",
                    provider: .apple,
                    createdAt: Date()
                )
                self.currentUser = previewUser
                self.destination = .tab(TabFeature.State(currentUser: previewUser))
            } else {
                self.destination = .login(LoginFeature.State())
            }
            #else
            self.destination = .login(LoginFeature.State())
            #endif
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

        @CasePathable
        public enum Destination {
            case login(LoginFeature.Action)
            case tab(TabFeature.Action)
        }
    }

    @Dependency(\.authClient) private var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let client = authClient
                return .run { send in
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
                }

            case .authStateChanged(let user):
                state.currentUser = user
                if let user {
                    if case .login = state.destination {
                        state.destination = .tab(TabFeature.State(currentUser: user))
                        if let pendingDeepLink = state.pendingDeepLink {
                            state.pendingDeepLink = nil
                            return .send(.deepLink(pendingDeepLink))
                        }
                    }
                } else {
                    state.destination = .login(LoginFeature.State())
                }
                return .none

            case .deepLink(let deepLink):
                switch deepLink {
                case .inviteCode(let code):
                    if case .tab = state.destination {
                        return .send(.destination(.tab(.showInviteCode(code))))
                    } else {
                        state.pendingDeepLink = deepLink
                    }
                case .videoDetail:
                    if case .tab = state.destination {
                        // TODO: Implement video deep link navigation
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
                state.currentUser = nil
                state.destination = .login(LoginFeature.State())
                return .none

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
