import SwiftUI
import ComposableArchitecture

public struct AppView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true
    @State private var bugReportDraft: BugReportDraft?

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            appContent

            ShakeDetectorView {
                guard !isShowingSplash, bugReportDraft == nil else { return }
                bugReportDraft = BugReportDraft.capture(user: store.currentUser)
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)

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
        .sheet(item: $bugReportDraft) { draft in
            BugReportView(draft: draft)
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
                FMToast(
                    message: toast.message,
                    type: mapToastType(toast.type),
                    onDismiss: {
                        store.send(
                            .toastDismissed,
                            animation: reduceMotion ? nil : .default
                        )
                    }
                )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .default, value: store.toast)
        .overlay {
            // 온보딩보다 아래에 깔린다 — 온보딩 완료 후 노출
            if let termsStore = store.scope(state: \.termsConsent, action: \.termsConsent) {
                TermsConsentView(store: termsStore)
                    .transition(.opacity)
            }
        }
        .overlay {
            if let onboardingStore = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboardingStore)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.onboarding != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.termsConsent != nil)
    }

    private func mapToastType(_ type: ToastState.ToastType) -> FMToast.ToastType {
        switch type {
        case .success: return .success
        case .error: return .error
        case .info: return .info
        }
    }
}
