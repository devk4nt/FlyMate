import SwiftUI
import ComposableArchitecture

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                // 프로필 섹션
                Section {
                    Button {
                        store.send(.profileEditTapped)
                    } label: {
                        HStack(spacing: FMSpacing.md) {
                            Circle()
                                .fill(FMColors.secondaryBackground)
                                .frame(width: 56, height: 56)
                                .overlay {
                                    Text(String(store.currentUser.name.prefix(1)))
                                        .font(FMTypography.title2)
                                        .foregroundStyle(FMColors.accent)
                                }

                            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                                Text(store.currentUser.name)
                                    .font(FMTypography.headline)
                                    .foregroundStyle(FMColors.label)
                                Text(store.currentUser.email)
                                    .font(FMTypography.caption1)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(FMColors.secondaryLabel)
                        }
                    }
                }

                // 구독
                Section("구독") {
                    Button {
                        store.send(.subscriptionTapped)
                    } label: {
                        Label("구독 관리", systemImage: "crown")
                            .foregroundStyle(FMColors.label)
                    }
                }

                // 스터디 관리
                Section("스터디") {
                    Button {
                        store.send(.studyManagementTapped)
                    } label: {
                        Label("스터디 관리", systemImage: "person.3")
                            .foregroundStyle(FMColors.label)
                    }
                }

                // 알림 설정
                Section("알림") {
                    Toggle(isOn: $store.notificationsEnabled.sending(\.notificationToggled)) {
                        Label("푸시 알림", systemImage: "bell")
                    }
                }

                // 계정
                Section("계정") {
                    Button {
                        store.send(.signOutTapped)
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(FMColors.label)
                    }

                    Button {
                        store.send(.deleteAccountTapped)
                    } label: {
                        Label("회원 탈퇴", systemImage: "person.crop.circle.badge.minus")
                            .foregroundStyle(FMColors.destructive)
                    }
                }

                // 앱 정보
                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
            }
            .navigationTitle("설정")
        }
        .alert($store.scope(state: \.confirmAlert, action: \.confirmAlert))
        .sheet(item: $store.scope(state: \.destination?.profileEdit, action: \.destination.profileEdit)) { editStore in
            NavigationStack {
                ProfileEditView(store: editStore)
            }
        }
        .sheet(item: $store.scope(state: \.destination?.studyManagement, action: \.destination.studyManagement)) { mgmtStore in
            NavigationStack {
                StudyManagementView(store: mgmtStore)
            }
        }
        .sheet(item: $store.scope(state: \.destination?.subscription, action: \.destination.subscription)) { subStore in
            NavigationStack {
                SubscriptionView(store: subStore)
            }
        }
    }
}
