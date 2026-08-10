import SwiftUI
import UIKit
import ComposableArchitecture

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    profileCard
                }
                .listRowInsets(EdgeInsets(
                    top: FMSpacing.xs,
                    leading: FMSpacing.md,
                    bottom: FMSpacing.md,
                    trailing: FMSpacing.md
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section("서비스") {
                    Button {
                        store.send(.subscriptionTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "crown.fill",
                            title: "구독 관리",
                            description: "플랜과 이용 한도를 확인해요",
                            tint: FMColors.brandRed
                        )
                    }

                    Button {
                        store.send(.studyManagementTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "person.3.fill",
                            title: "스터디 관리",
                            description: "참여 중인 스터디를 관리해요",
                            tint: FMColors.brandInk
                        )
                    }
                }
                .settingsSectionStyle()

                Section("알림") {
                    Toggle(isOn: $store.notificationsEnabled.sending(\.notificationToggled)) {
                        SettingsActionLabel(
                            systemImage: "bell.fill",
                            title: "푸시 알림",
                            description: "새 피드백과 스터디 소식을 받아요",
                            tint: FMColors.airBlue,
                            showsChevron: false
                        )
                    }
                    .tint(FMColors.brandInk)
                }
                .settingsSectionStyle()

                Section("고객 지원") {
                    Button {
                        store.send(.developerContactTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "envelope.fill",
                            title: "개발자에게 문의하기",
                            description: "버그와 개선 의견을 이메일로 보내요",
                            tint: FMColors.airBlue
                        )
                    }
                    .accessibilityHint("메일 앱을 열어 문의 메일을 작성합니다")
                }
                .settingsSectionStyle()

                Section("계정") {
                    Button {
                        store.send(.signOutTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "rectangle.portrait.and.arrow.right",
                            title: "로그아웃",
                            description: "현재 계정에서 로그아웃해요",
                            tint: FMColors.secondaryLabel,
                            showsChevron: false
                        )
                    }

                    Button {
                        store.send(.deleteAccountTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "person.crop.circle.badge.minus",
                            title: "회원 탈퇴",
                            description: "계정과 모든 데이터를 삭제해요",
                            tint: FMColors.destructive,
                            isDestructive: true,
                            showsChevron: false
                        )
                    }
                }
                .settingsSectionStyle()

                Section("앱 정보") {
                    HStack {
                        SettingsActionLabel(
                            systemImage: "info.circle.fill",
                            title: "FlyMate 버전",
                            description: "더 나은 면접 연습을 함께 만들어요",
                            tint: FMColors.brandInk,
                            showsChevron: false
                        )

                        Spacer()

                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
                .settingsSectionStyle()
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(FMSpacing.lg)
            .scrollContentBackground(.hidden)
            .background(FMColors.softCanvas)
            .tint(FMColors.brandInk)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.send(.onAppear) }
        // 시스템 설정에서 권한 변경 후 복귀 시 토글 상태 재동기화
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            store.send(.onAppear)
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

    private var profileCard: some View {
        Button {
            store.send(.profileEditTapped)
        } label: {
            HStack(spacing: FMSpacing.md) {
                FMProfileImage(
                    url: store.currentUser.profileImageURL,
                    name: store.currentUser.name,
                    size: .xl
                )
                .background(.white.opacity(0.92), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: 2)
                }

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("MY FLYMATE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.76))

                    Text(store.currentUser.name)
                        .font(FMTypography.sectionTitle)
                        .foregroundStyle(.white)

                    Text(store.currentUser.displayEmail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .padding(FMSpacing.lg)
            .background(FMColors.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
            .shadow(color: FMColors.brandInk.opacity(0.18), radius: 16, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.currentUser.name), \(store.currentUser.displayEmail), 프로필 편집")
        .accessibilityHint("프로필 정보를 수정하려면 이중 탭하세요")
    }
}

private struct SettingsActionLabel: View {
    let systemImage: String
    let title: String
    let description: String
    let tint: Color
    var isDestructive = false
    var showsChevron = true

    var body: some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDestructive ? FMColors.destructive : FMColors.label)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            if showsChevron {
                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FMColors.secondaryLabel.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
    }
}

private extension View {
    func settingsSectionStyle() -> some View {
        self
            .listRowBackground(FMColors.background)
            .listRowSeparatorTint(FMColors.airBlue.opacity(0.18))
    }
}
