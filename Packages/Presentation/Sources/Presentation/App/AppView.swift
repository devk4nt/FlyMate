import SwiftUI
import ComposableArchitecture

public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
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
    }

    private func mapToastType(_ type: ToastState.ToastType) -> FMToast.ToastType {
        switch type {
        case .success: return .success
        case .error: return .error
        case .info: return .info
        }
    }
}
