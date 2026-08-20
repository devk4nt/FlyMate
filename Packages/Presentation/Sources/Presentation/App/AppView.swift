import SwiftUI
import ComposableArchitecture

public struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
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
        .sheet(item: $store.scope(state: \.announcement, action: \.announcement)) { announcementStore in
            AnnouncementDetailView(store: announcementStore)
                .interactiveDismissDisabled()
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
        .task(id: isShowingSplash ? nil : store.startupAnnouncementUserID) {
            guard !isShowingSplash, store.startupAnnouncementUserID != nil else { return }
            // 스플래시가 걷히고 홈이 먼저 보인 뒤에 공지를 띄운다
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            store.send(.startupAnnouncementRequested)
        }
    }

    private func mapToastType(_ type: ToastState.ToastType) -> FMToast.ToastType {
        switch type {
        case .success: return .success
        case .error: return .error
        case .info: return .info
        }
    }
}
