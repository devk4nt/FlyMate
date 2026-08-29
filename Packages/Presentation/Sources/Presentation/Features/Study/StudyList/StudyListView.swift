import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyListView: View {
    @Bindable var store: StoreOf<StudyListFeature>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let heroPhrases = [
        "오늘도 한 번, 더 자신 있게",
        "카메라 앞에서도 나답게",
        "연습한 만큼 자연스러워져요",
        "오늘의 연습이 내일의 합격",
        "떨림도 준비의 일부예요",
        "시선은 정면, 마음은 편안하게",
        "미소가 가장 좋은 첫인상",
        "한 번 더, 어제보다 나아지게",
        "목소리에 자신감을 담아서",
        "준비된 만큼 흔들리지 않아요",
        "실전처럼, 매일 꾸준히",
        "나의 속도로, 멈추지 않고",
        "좋은 피드백이 성장의 지름길",
        "반복이 실력을 만들어요",
        "긴장은 잘하고 싶다는 증거",
        "오늘도 밝게, 또렷하게",
        "함께 연습하면 더 멀리 가요",
        "어제의 나와 비교하면 충분해요",
        "첫 문장부터 당당하게",
        "합격의 순간을 그리며 한 번 더",
    ]
    @State private var heroPhrase = Self.heroPhrases.randomElement() ?? "오늘도 한 번, 더 자신 있게"

    public init(store: StoreOf<StudyListFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FMSpacing.lg) {
                practiceHero(studies: loadedStudies)
                quickFeedbackOverview
                studyContent
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .background(FMColors.canvas)
        .refreshable {
            await store.send(.refresh).finish()
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
                    FMSkeletonView.card
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
        FMCard(style: .hero, background: FMColors.supportSurface) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.sm) {
                    FMPracticeSymbol(size: 48)

                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        Text(store.awaitingFirstUpload ? "첫 영상을 올려 피드백을 받아보세요" : heroPhrase)
                            .font(FMTypography.headline)
                            .foregroundStyle(FMColors.brandTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if store.awaitingFirstUpload {
                            Text("\(Int(AppConstants.maxQuickFeedbackVideoDurationSeconds))초 영상이면 충분해요")
                                .font(FMTypography.caption1)
                                .monospacedDigit()
                                .foregroundStyle(FMColors.secondaryLabel)
                        } else if let studies {
                            Text("스터디 \(studies.count)개 · 함께하는 멤버 \(studies.reduce(0) { $0 + $1.memberCount })명")
                                .font(FMTypography.caption1)
                                .monospacedDigit()
                                .foregroundStyle(FMColors.secondaryLabel)
                        }
                    }

                    Spacer(minLength: 0)
                }

                heroActions
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var heroActions: some View {
        FMGlassContainer(spacing: FMSpacing.xs) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: FMSpacing.xs) {
                    quickFeedbackHeroAction
                    createStudyAction
                    joinStudyAction
                }
            } else {
                HStack(spacing: FMSpacing.xs) {
                    quickFeedbackHeroAction
                    createStudyAction
                    joinStudyAction
                }
            }
        }
    }

    private var quickFeedbackHeroAction: some View {
        heroActionButton(
            title: store.awaitingFirstUpload ? "첫 영상 올리기" : "연습 시작",
            systemImage: "video.badge.plus",
            isPrimary: true
        ) {
            store.send(.quickFeedbackPrimaryTapped)
        }
        .background(FMColors.primaryAction, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
        .accessibilityHint("스터디 없이 빠른 피드백을 요청합니다")
    }

    private var createStudyAction: some View {
        heroActionButton(
            title: "만들기",
            systemImage: "plus",
            isPrimary: false
        ) {
            store.send(.createStudyTapped)
        }
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
        .accessibilityHint("새 스터디를 만듭니다")
    }

    private var joinStudyAction: some View {
        heroActionButton(
            title: "코드 참여",
            systemImage: "ticket",
            isPrimary: false
        ) {
            store.send(.joinStudyTapped)
        }
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
        .accessibilityHint("초대 코드로 스터디에 참여합니다")
    }

    private func heroActionButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(FMTypography.feedMetaEmphasis)
                .foregroundStyle(isPrimary ? FMColors.onAccent : FMColors.brandTitle)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var quickFeedbackOverview: some View {
        switch store.quickFeedback {
        case .idle, .loading:
            FMSkeletonView.card
        case .failed:
            Button { store.send(.quickFeedbackHubTapped) } label: {
                FMCard {
                    Label("빠른 피드백 상태를 확인해보세요", systemImage: "arrow.clockwise")
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        case .loaded(let dashboard):
            Button { store.send(.quickFeedbackHubTapped) } label: {
                FMCard(style: .feed) {
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        HStack(spacing: FMSpacing.sm) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(FMColors.iconAccent)
                            Text("빠른 피드백")
                                .font(FMTypography.sectionTitle)
                                .foregroundStyle(FMColors.brandTitle)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(FMTypography.feedMetaEmphasis)
                                .foregroundStyle(FMColors.secondaryLabel)
                        }

                        if let request = dashboard.latestRequest, request.status == .open {
                            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                                HStack {
                                    Text("내 요청 진행 중")
                                        .font(FMTypography.authorName)
                                        .foregroundStyle(FMColors.label)
                                    Spacer()
                                    Text("\(request.feedbackCount)/\(request.targetFeedbackCount)")
                                        .font(FMTypography.feedMetaEmphasis)
                                        .foregroundStyle(FMColors.secondaryLabel)
                                        .monospacedDigit()
                                }
                                ProgressView(
                                    value: Double(request.feedbackCount),
                                    total: Double(request.targetFeedbackCount)
                                )
                                .tint(FMColors.primary)
                            }
                        } else {
                            Text("다른 사람의 영상에 피드백을 남기고, 내 영상도 피드백 받아보세요.")
                                .font(FMTypography.callout)
                                .foregroundStyle(FMColors.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack {
                            Label(
                                "피드백할 영상 \(dashboard.availableRequests.count)개",
                                systemImage: "play.rectangle.on.rectangle"
                            )
                            .font(FMTypography.feedMetaEmphasis)
                            .foregroundStyle(FMColors.iconAccent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(FMColors.secondaryLabel)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("빠른 피드백 요청과 피드백할 영상을 확인합니다")
        }
    }

    private func sectionHeader(count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("내 스터디")
                .font(FMTypography.sectionTitle)
                .foregroundStyle(FMColors.brandTitle)

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
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
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
                        .foregroundStyle(FMColors.brandTitle)

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

#Preview("스터디 없음 (신규 유저)") {
    var state = StudyListFeature.State()
    state.studies = .loaded([])
    state.quickFeedback = .loaded(
        QuickFeedbackDashboard(myRequests: [], availableRequests: [], receivedReviews: [])
    )
    return NavigationStack {
        StudyListView(store: Store(initialState: state) { StudyListFeature() })
    }
}
