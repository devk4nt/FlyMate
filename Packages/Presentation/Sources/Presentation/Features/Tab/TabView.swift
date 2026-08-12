import SwiftUI
import ComposableArchitecture

public struct MainTabView: View {
    @Bindable var store: StoreOf<TabFeature>

    public init(store: StoreOf<TabFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            StudyNavigationView(
                store: store.scope(state: \.study, action: \.study)
            )
            .tabItem {
                Label("스터디", systemImage: "person.3")
            }
            .tag(TabFeature.State.Tab.study)

            RecruitListView(
                store: store.scope(state: \.recruit, action: \.recruit)
            )
            .tabItem {
                Label("모집", systemImage: "megaphone")
            }
            .tag(TabFeature.State.Tab.recruit)

            FeedbackManagementView(
                store: store.scope(state: \.feedbackManagement, action: \.feedbackManagement)
            )
            .tabItem {
                Label("피드백", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(TabFeature.State.Tab.feedback)

            SettingsView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .tabItem {
                Label("설정", systemImage: "gearshape")
            }
            .tag(TabFeature.State.Tab.settings)
        }
        .tint(FMColors.actionForeground)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: Binding(
            get: { store.isNotificationSheetPresented },
            set: { newValue in
                if !newValue {
                    store.send(.dismissNotificationSheet)
                }
            }
        )) {
            NavigationStack {
                NotificationListView(
                    store: store.scope(state: \.notificationList, action: \.notificationList)
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") {
                            store.send(.dismissNotificationSheet)
                        }
                    }
                }
            }
        }
    }
}
