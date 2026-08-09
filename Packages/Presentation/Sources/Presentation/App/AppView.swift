import SwiftUI
import ComposableArchitecture

public struct AppView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            appContent

            if isShowingSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }
        }
        .task {
            guard isShowingSplash else { return }

            let duration: UInt64 = reduceMotion ? 700_000_000 : 1_450_000_000
            try? await Task.sleep(nanoseconds: duration)

            withAnimation(reduceMotion ? .linear(duration: 0.15) : .easeOut(duration: 0.4)) {
                isShowingSplash = false
            }
        }
    }

    private var appContent: some View {
        Group {
            switch store.destination {
            case .login:
                if let loginStore = store.scope(state: \.loginState, action: \.destination.login) {
                    LoginView(store: loginStore)
                }
            case .tab:
                if let tabStore = store.scope(state: \.tabState, action: \.destination.tab) {
                    MainTabView(store: tabStore)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                FMToast(message: toast.message, type: mapToastType(toast.type))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            store.send(.toastDismissed, animation: .default)
                        }
                    }
            }
        }
        .animation(.default, value: store.toast)
        .overlay {
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboardingStore)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.onboarding != nil)
    }

    private func mapToastType(_ type: ToastState.ToastType) -> FMToast.ToastType {
        switch type {
        case .success: return .success
        case .error: return .error
        case .info: return .info
        }
    }
}
