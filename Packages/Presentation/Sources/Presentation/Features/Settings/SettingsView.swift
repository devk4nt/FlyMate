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
                        store.send(.myActivityTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "chart.bar.fill",
                            title: "나의 활동",
                            description: "올린 영상과 피드백 활동을 확인해요",
                            tint: FMColors.accent
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

                    Button {
                        store.send(.blockedUsersTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "person.crop.circle.badge.xmark",
                            title: "차단한 사용자",
                            description: "차단한 사용자를 관리해요",
                            tint: FMColors.secondaryLabel
                        )
                    }
                }
                .settingsSectionStyle()

                Section("현직자 인증") {
                    Button {
                        store.send(.verificationRequestTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "checkmark.seal.fill",
                            title: "현직자 인증하기",
                            description: "재직·합격 증명으로 현직자 뱃지를 받아요",
                            tint: FMColors.accent
                        )
                    }
                    .accessibilityHint("메일 앱을 열어 현직자 인증 신청 메일을 작성합니다")
                }
                .settingsSectionStyle()

                Section("알림") {
                    Toggle(isOn: $store.notificationsEnabled.sending(\.notificationToggled)) {
                        SettingsActionLabel(
                            systemImage: "bell.fill",
                            title: "푸시 알림",
                            description: "새 피드백과 스터디 소식을 받아요",
                            tint: FMColors.accent,
                            showsChevron: false
                        )
                    }
                    .tint(FMColors.actionForeground)

                    Toggle(isOn: $store.smileReminderEnabled.sending(\.smileReminderToggled)) {
                        SettingsActionLabel(
                            systemImage: "face.smiling.inverse",
                            title: "1일 1미소 알림",
                            description: "매일 정해진 시간에 미소 연습을 알려드려요",
                            tint: FMColors.attentionFill,
                            showsChevron: false
                        )
                    }
                    .tint(FMColors.actionForeground)

                    if store.smileReminderEnabled {
                        DatePicker(
                            "알림 시간",
                            selection: Binding(
                                get: { smileReminderDate },
                                set: { store.send(.smileReminderTimeChanged($0)) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .font(FMTypography.body)
                        .accessibilityHint("1일 1미소 알림을 받을 시간을 선택합니다")
                    }
                }
                .settingsSectionStyle()

                Section("고객 지원") {
                    Button {
                        store.send(.rateAppTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "star.fill",
                            title: "FlyMate 평가하기",
                            description: "App Store에 별점과 리뷰를 남겨요",
                            tint: FMColors.warning
                        )
                    }
                    .accessibilityHint("App Store 리뷰 작성 화면을 엽니다")

                    Button {
                        store.send(.developerContactTapped)
                    } label: {
                        SettingsActionLabel(
                            systemImage: "envelope.fill",
                            title: "개발자에게 문의하기",
                            description: "버그와 개선 의견을 이메일로 보내요",
                            tint: FMColors.accent
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
                    Button {
                        store.send(.clearCacheTapped)
                    } label: {
                        HStack {
                            SettingsActionLabel(
                                systemImage: "photo.stack",
                                title: "이미지 캐시 비우기",
                                description: "저장된 이미지 캐시를 삭제해 공간을 확보해요",
                                tint: FMColors.brandInk,
                                showsChevron: false
                            )

                            Spacer()

                            switch store.cacheSize {
                            case .idle, .loading:
                                ProgressView()

                            case .loaded(let bytes):
                                Text(formattedCacheSize(bytes))
                                    .font(FMTypography.authorName)
                                    .foregroundStyle(FMColors.secondaryLabel)

                            case .failed:
                                Text("계산 실패")
                                    .font(FMTypography.authorName)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }
                        }
                    }
                    .accessibilityLabel("이미지 캐시 비우기")
                    .accessibilityHint("저장된 이미지 캐시를 삭제합니다")

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
                            .font(FMTypography.authorName)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
                .settingsSectionStyle()

                #if DEBUG
                // Crashlytics 동작 검증용 임시 섹션 — 검증 후 삭제
                Section("개발자") {
                    Button("테스트 크래시 발생") {
                        fatalError("Crashlytics test crash")
                    }
                    .foregroundStyle(FMColors.destructive)
                }
                .settingsSectionStyle()
                #endif
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(FMSpacing.lg)
            .scrollContentBackground(.hidden)
            .background(FMColors.canvas)
            .tint(FMColors.actionForeground)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $store.isStudyManagementActive.sending(\.studyManagementActiveChanged)) {
                StudyManagementView(store: store.scope(state: \.studyManagement, action: \.studyManagement))
            }
            .navigationDestination(isPresented: $store.isBlockedUsersActive.sending(\.blockedUsersActiveChanged)) {
                BlockedUsersView(store: store.scope(state: \.blockedUsers, action: \.blockedUsers))
            }
        }
        .background(FMColors.canvas)
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
            .interactiveDismissDisabled(editStore.hasChanges)
        }
        .sheet(item: $store.scope(state: \.destination?.myActivity, action: \.destination.myActivity)) { activityStore in
            MyActivitySheet(store: activityStore)
        }
    }

    private var smileReminderDate: Date {
        Calendar.current.date(
            bySettingHour: store.smileReminderMinutes / 60,
            minute: store.smileReminderMinutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private var profileCard: some View {
        Button {
            store.send(.profileEditTapped)
        } label: {
            FMCard(style: .feed, background: FMColors.supportSurface) {
                HStack(spacing: FMSpacing.sm) {
                    FMProfileImage(
                        url: store.currentUser.profileImageURL,
                        name: store.currentUser.name,
                        size: .lg
                    )

                    VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                        HStack(spacing: FMSpacing.xxs) {
                            Text(store.currentUser.name)
                                .font(FMTypography.headline)
                                .foregroundStyle(FMColors.brandTitle)

                            FMVerifiedBadge(userID: store.currentUser.id)
                        }

                        Text(store.currentUser.displayEmail)
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Label("편집", systemImage: "pencil")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.primaryAction)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.currentUser.name), \(store.currentUser.displayEmail), 프로필 편집")
        .accessibilityHint("프로필 정보를 수정하려면 이중 탭하세요")
    }

    private func formattedCacheSize(_ bytes: UInt) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
                .font(.system(size: FMSizing.IconSize.sm, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: FMSizing.IconContainer.sm, height: FMSizing.IconContainer.sm)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(title)
                    .font(FMTypography.authorName)
                    .foregroundStyle(isDestructive ? FMColors.destructive : FMColors.label)

                Text(description)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            if showsChevron {
                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(FMTypography.feedMetaEmphasis)
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
            .listRowSeparatorTint(FMColors.supportAccent.opacity(0.18))
    }
}
