import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyListView: View {
    @Bindable var store: StoreOf<StudyListFeature>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(store: StoreOf<StudyListFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FMSpacing.xl) {
                practiceHero(studies: loadedStudies)
                studyContent
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
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
            .fmSheetStyle()
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
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Label("TODAY'S PRACTICE", systemImage: "sparkles")
                    .font(FMTypography.badgeStrong)
                    .tracking(0.8)
                    .foregroundStyle(FMColors.onBrand)

                Text("오늘도 한 번, 더 자신 있게")
                    .font(FMTypography.sectionTitle)
                    .foregroundStyle(.white)
            }

            if let studies {
                Text("참여 중인 스터디 \(studies.count)개 · 멤버 \(studies.reduce(0) { $0 + $1.memberCount })명")
                    .font(FMTypography.caption1)
                    .monospacedDigit()
                    .foregroundStyle(FMColors.onBrand)
            }

            heroActions
        }
        .padding(.horizontal, FMSpacing.lg)
        .padding(.vertical, FMSpacing.md)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.hero, style: .continuous)
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
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.hero, style: .continuous))
        }
        .shadow(color: FMShadow.heroColor, radius: FMShadow.heroRadius, y: FMShadow.heroY)
        .accessibilityElement(children: .contain)
    }

    private var heroActions: some View {
        FMGlassContainer(spacing: FMSpacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: FMSpacing.sm) {
                    primaryHeroAction
                    secondaryHeroAction
                }
            } else {
                HStack(spacing: FMSpacing.sm) {
                    primaryHeroAction
                    secondaryHeroAction
                }
            }
        }
    }

    private var primaryHeroAction: some View {
        heroActionButton(
            title: "스터디 만들기",
            systemImage: "plus",
            isPrimary: true
        ) {
            store.send(.createStudyTapped)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
        .fmGlass(tint: .white.opacity(0.92))
    }

    private var secondaryHeroAction: some View {
        heroActionButton(
            title: "코드로 참여",
            systemImage: "ticket",
            isPrimary: false
        ) {
            store.send(.joinStudyTapped)
        }
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
        .fmGlass(tint: .white.opacity(0.52))
    }

    private func heroActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(FMTypography.authorName)
                .foregroundStyle(FMColors.iconAccent)
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
                    .font(FMTypography.authorName)
                    .foregroundStyle(FMColors.badgeForeground)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyStudyCard: some View {
        FMCard(style: .feed, padding: 0) {
            FMEmptyState(
                systemImage: "person.3.sequence.fill",
                title: "함께 연습할 스터디를 찾아보세요",
                description: "직접 만들거나 초대 코드로 참여할 수 있어요.",
                layout: .compact
            )
        }
    }
}

// MARK: - Study Row

private struct StudyRow: View {
    let study: Domain.Study

    var body: some View {
        FMCard(style: .feed) {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                HStack(spacing: FMSpacing.sm) {
                    memberStack

                    Text("멤버 \(study.memberCount)명")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(FMTypography.badgeStrong)
                        .foregroundStyle(FMColors.iconAccent)
                        .frame(width: 30, height: 30)
                        .background(FMColors.iconAccent.opacity(0.12), in: Circle())
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text(study.name)
                        .font(FMTypography.cardTitle)
                        .foregroundStyle(FMColors.label)

                    Text(study.description)
                        .font(FMTypography.feedBody)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notice = study.notice, !notice.isEmpty {
                    HStack(spacing: FMSpacing.xs) {
                        Image(systemName: "megaphone.fill")
                            .foregroundStyle(FMColors.iconAccent)

                        Text(notice)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .padding(.horizontal, FMSpacing.sm)
                    .padding(.vertical, FMSpacing.xs)
                    .background(FMColors.iconAccent.opacity(0.09), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    .font(FMTypography.eyebrow)
                    .foregroundStyle(FMColors.badgeForeground)
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
