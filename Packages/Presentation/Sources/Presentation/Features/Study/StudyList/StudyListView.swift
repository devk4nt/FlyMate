import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyListView: View {
    @Bindable var store: StoreOf<StudyListFeature>

    public init(store: StoreOf<StudyListFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FMSpacing.xl) {
                practiceHero(studies: loadedStudies)
                studyContent
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .background(FMColors.softCanvas)
        .refreshable {
            store.send(.refresh)
        }
        .navigationTitle("FlyMate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if #available(iOS 26.0, macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    notificationAction
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) {
                    notificationAction
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(item: $store.scope(state: \.createStudy, action: \.createStudy)) { createStore in
            NavigationStack {
                StudyCreateView(store: createStore)
            }
        }
        .sheet(item: $store.scope(state: \.joinStudy, action: \.joinStudy)) { joinStore in
            NavigationStack {
                JoinStudyView(store: joinStore)
            }
            .presentationDetents([.medium])
        }
    }

    private var loadedStudies: [Study]? {
        guard case .loaded(let studies) = store.studies else { return nil }
        return studies
    }

    private var notificationAction: some View {
        FMNotificationBell(unreadCount: store.unreadNotificationCount) {
            store.send(.notificationBellTapped)
        }
    }

    @ViewBuilder
    private var studyContent: some View {
        switch store.studies {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                sectionHeader(count: nil)
                ForEach(0..<2, id: \.self) { _ in
                    FMSkeletonView(height: 168)
                }
            }

        case .loaded(let studies):
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                sectionHeader(count: studies.count)

                if studies.isEmpty {
                    emptyStudyCard
                } else {
                    ForEach(studies) { study in
                        Button {
                            store.send(.studyTapped(study))
                        } label: {
                            StudyRow(study: study)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.refresh)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FMSpacing.xxl)
        }
    }

    private func practiceHero(studies: [Study]?) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.lg) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Label("TODAY'S PRACTICE", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.82))

                Text("오늘도 한 번, 더 자신 있게")
                    .font(FMTypography.sectionTitle)
                    .foregroundStyle(.white)
            }

            if let studies {
                HStack(spacing: FMSpacing.sm) {
                    heroMetric(
                        value: "\(studies.count)",
                        label: "참여 중인 스터디"
                    )
                    heroMetric(
                        value: "\(studies.reduce(0) { $0 + $1.memberCount })",
                        label: "함께하는 멤버"
                    )
                }
            }

            heroActions
        }
        .padding(FMSpacing.lg)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(FMColors.brandGradient)

                Circle()
                    .fill(FMColors.secondary.opacity(0.34))
                    .frame(width: 150, height: 150)
                    .blur(radius: 4)
                    .offset(x: 56, y: -62)

                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 90, height: 90)
                    .offset(x: -30, y: 128)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .shadow(color: FMColors.brandInk.opacity(0.2), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func heroMetric(value: String, label: String) -> some View {
        HStack(spacing: FMSpacing.xs) {
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()

            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, FMSpacing.sm)
        .padding(.vertical, FMSpacing.xs)
        .background(.white.opacity(0.13), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroActions: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.sm) {
                    heroActionButton(
                        title: "스터디 만들기",
                        systemImage: "plus",
                        isPrimary: true
                    ) {
                        store.send(.createStudyTapped)
                    }
                    .glassEffect(
                        .regular.tint(.white.opacity(0.92)).interactive(),
                        in: .rect(cornerRadius: FMSpacing.CornerRadius.md)
                    )

                    heroActionButton(
                        title: "코드로 참여",
                        systemImage: "ticket",
                        isPrimary: false
                    ) {
                        store.send(.joinStudyTapped)
                    }
                    .glassEffect(
                        .regular.tint(.white.opacity(0.52)).interactive(),
                        in: .rect(cornerRadius: FMSpacing.CornerRadius.md)
                    )
                }
            }
        } else {
            HStack(spacing: FMSpacing.sm) {
                heroActionButton(
                    title: "스터디 만들기",
                    systemImage: "plus",
                    isPrimary: true
                ) {
                    store.send(.createStudyTapped)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))

                heroActionButton(
                    title: "코드로 참여",
                    systemImage: "ticket",
                    isPrimary: false
                ) {
                    store.send(.joinStudyTapped)
                }
                .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
            }
        }
    }

    private func heroActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FMColors.brandInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isPrimary ? "새 스터디를 만듭니다" : "초대 코드로 스터디에 참여합니다")
    }

    private func sectionHeader(count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("내 스터디")
                .font(FMTypography.sectionTitle)
                .foregroundStyle(FMColors.label)

            Spacer()

            if let count {
                Text("\(count)개")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.brandInk)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyStudyCard: some View {
        VStack(spacing: FMSpacing.md) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: FMSizing.IconSize.hero, weight: .medium))
                .foregroundStyle(FMColors.brandInk)

            VStack(spacing: FMSpacing.xs) {
                Text("함께 연습할 스터디를 찾아보세요")
                    .font(.headline)
                    .foregroundStyle(FMColors.label)

                Text("직접 만들거나 초대 코드로 참여할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMSpacing.xxl)
        .padding(.horizontal, FMSpacing.lg)
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.airBlue.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Study Row

private struct StudyRow: View {
    let study: Domain.Study

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            HStack(spacing: FMSpacing.sm) {
                memberStack

                Text("멤버 \(study.memberCount)명")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FMColors.secondaryLabel)

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FMColors.brandInk)
                    .frame(width: 30, height: 30)
                    .background(FMColors.airBlue.opacity(0.12), in: Circle())
            }

            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                Text(study.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(FMColors.label)

                Text(study.description)
                    .font(.subheadline)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notice = study.notice, !notice.isEmpty {
                HStack(spacing: FMSpacing.xs) {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(FMColors.brandInk)

                    Text(notice)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(FMColors.secondaryLabel)
                .padding(.horizontal, FMSpacing.sm)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMSpacing.lg)
        .background(FMColors.background)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.airBlue.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: FMColors.brandInk.opacity(0.07), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(study.name), 멤버 \(study.memberCount)명, 최대 \(study.maxMembers)명")
        .accessibilityHint("스터디의 영상과 피드백을 보려면 이중 탭하세요")
    }

    private var memberStack: some View {
        HStack(spacing: -FMSpacing.xs) {
            ForEach(Array(study.members.prefix(3))) { member in
                FMProfileImage(
                    url: member.profileImageURL,
                    name: member.userName,
                    size: .md
                )
                .overlay {
                    Circle()
                        .stroke(FMColors.background, lineWidth: 2)
                }
            }

            if study.memberCount > 3 {
                Text("+\(study.memberCount - 3)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FMColors.brandInk)
                    .frame(width: 32, height: 32)
                    .background(FMColors.softCanvas, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(FMColors.background, lineWidth: 2)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}
