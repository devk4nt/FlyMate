import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct RecruitListView: View {
    @Bindable var store: StoreOf<RecruitListFeature>

    public init(store: StoreOf<RecruitListFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FMColors.canvas)
                .navigationTitle("모집")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.createTapped)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("모집 글 작성")
                        .accessibilityHint("새 스터디원 모집 글을 작성합니다")
                        .accessibilityIdentifier("스터디_목록_모집글작성")
                    }
                }
                .onAppear { store.send(.onAppear) }
                .navigationDestination(item: $store.scope(state: \.detail, action: \.detail)) { detailStore in
                    RecruitDetailView(store: detailStore)
                }
                .sheet(item: $store.scope(state: \.create, action: \.create)) { createStore in
                    NavigationStack {
                        RecruitCreateView(store: createStore)
                    }
                    .interactiveDismissDisabled(createStore.hasChanges)
                }
                .sheet(item: $store.scope(state: \.createStudy, action: \.createStudy)) { createStudyStore in
                    NavigationStack {
                        StudyCreateView(store: createStudyStore)
                    }
                }
                .sheet(item: $store.scope(state: \.userActivity, action: \.userActivity)) { activityStore in
                    MyActivitySheet(store: activityStore)
                }
                .fmToast(
                    isPresented: Binding(
                        get: { store.showToast },
                        set: { _ in store.send(.toastDismissed) }
                    ),
                    message: store.toastMessage,
                    type: .success
                )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch store.loadingState {
        case .idle, .loading:
            ScrollView {
                VStack(spacing: FMSpacing.md) {
                    recruitmentHero
                    filterBar
                    ForEach(0..<3, id: \.self) { _ in
                        FMSkeletonView(height: 150)
                    }
                }
                .frame(maxWidth: FMSizing.ContentWidth.regular)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
            }

        case .loaded(let posts):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FMSpacing.md) {
                    recruitmentHero
                    filterBar

                    if posts.isEmpty {
                        emptyCard
                    } else {
                        ForEach(posts) { post in
                            RecruitPostRow(
                                post: post,
                                onProfileTapped: { store.send(.authorProfileTapped(post)) }
                            )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.postTapped(post))
                                }
                                .accessibilityIdentifier("스터디_목록_모집글_\(post.id.uuidString)")
                                .onAppear {
                                    if post == posts.last {
                                        store.send(.loadMore)
                                    }
                                }
                        }

                        if store.posts.isLoadingMore {
                            ProgressView()
                                .padding()
                        }
                    }
                }
                .frame(maxWidth: FMSizing.ContentWidth.regular)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxxl)
            }
            .refreshable {
                await store.send(.refresh).finish()
            }

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.refresh)
            }
        }
    }

    // MARK: - Hero

    private var recruitmentHero: some View {
        FMCard(style: .hero, background: FMColors.supportSurface) {
            HStack(spacing: FMSpacing.sm) {
                FMPracticeSymbol(size: 44, showsEncouragement: false)

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("스터디 모집")
                        .font(FMTypography.eyebrow)
                        .foregroundStyle(FMColors.supportAccent)

                    Text("함께 연습할 동료를 찾아보세요")
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.brandTitle)
                }

                Spacer(minLength: 0)

                Button {
                    store.send(.createTapped)
                } label: {
                    Label("글쓰기", systemImage: "square.and.pencil")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.onAccent)
                        .padding(.horizontal, FMSpacing.sm)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .background(
                    FMColors.primaryAction,
                    in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous)
                )
                .accessibilityHint("새 스터디원 모집 글을 작성합니다")
                .accessibilityIdentifier("스터디_목록_히어로_모집글작성")
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Filter

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text("모집 글")
                .font(FMTypography.sectionTitle)
                .foregroundStyle(FMColors.brandTitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FMSpacing.xs) {
                    filterChip(
                        title: "모집 중",
                        isActive: store.filter.recruitingOnly
                    ) {
                        store.send(.recruitingOnlyToggled)
                    }
                    .accessibilityIdentifier("스터디_목록_모집중필터")

                    Menu {
                        Button("전체") { store.send(.fieldFilterSelected(nil)) }
                        ForEach(RecruitField.allCases, id: \.self) { field in
                            Button(field.displayText) { store.send(.fieldFilterSelected(field)) }
                        }
                    } label: {
                        menuChipLabel(
                            title: store.filter.field?.displayText ?? "분야",
                            isActive: store.filter.field != nil
                        )
                    }
                    .accessibilityLabel("분야 필터")
                    .accessibilityIdentifier("스터디_목록_분야필터")

                    Menu {
                        Button("전체") { store.send(.meetingTypeFilterSelected(nil)) }
                        ForEach(RecruitMeetingType.allCases, id: \.self) { type in
                            Button(type.displayText) { store.send(.meetingTypeFilterSelected(type)) }
                        }
                    } label: {
                        menuChipLabel(
                            title: store.filter.meetingType?.displayText ?? "진행 방식",
                            isActive: store.filter.meetingType != nil
                        )
                    }
                    .accessibilityLabel("진행 방식 필터")
                    .accessibilityIdentifier("스터디_목록_진행방식필터")
                }
                .padding(.vertical, FMSpacing.xxs)
            }
        }
    }

    private func filterChip(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(title: title, isActive: isActive)
        }
        .accessibilityLabel("\(title) 필터")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func menuChipLabel(title: String, isActive: Bool) -> some View {
        HStack(spacing: FMSpacing.xxs) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(FMTypography.caption2)
        }
        .font(FMTypography.feedMetaEmphasis)
        .foregroundStyle(isActive ? FMColors.onAccent : FMColors.label)
        .padding(.horizontal, FMSpacing.sm)
        .padding(.vertical, FMSpacing.xs)
        .background(isActive ? FMColors.primaryAction : FMColors.background, in: Capsule())
        .overlay {
            Capsule().stroke(FMColors.border.opacity(0.4), lineWidth: isActive ? 0 : 1)
        }
    }

    private func chipLabel(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(FMTypography.feedMetaEmphasis)
            .foregroundStyle(isActive ? FMColors.onAccent : FMColors.label)
            .padding(.horizontal, FMSpacing.sm)
            .padding(.vertical, FMSpacing.xs)
        .background(isActive ? FMColors.primaryAction : FMColors.background, in: Capsule())
            .overlay {
                Capsule().stroke(FMColors.border.opacity(0.4), lineWidth: isActive ? 0 : 1)
            }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        FMCard(style: .feed, padding: 0) {
            FMEmptyState(
                systemImage: "megaphone",
                title: "아직 모집 글이 없어요",
                description: "첫 번째로 스터디원을 모집해보세요.",
                layout: .compact
            )
        }
    }
}

// MARK: - Row

struct RecruitPostRow: View {
    let post: RecruitPost
    let onProfileTapped: () -> Void

    var body: some View {
        FMCard(
            style: .feed,
            background: post.isRecruiting() ? FMColors.background : FMColors.secondaryBackground,
            border: post.isRecruiting() ? FMColors.supportAccent.opacity(0.2) : FMColors.border.opacity(0.3)
        ) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.xs) {
                    statusBadge

                    Text(post.field.displayText)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.badgeForeground)
                        .padding(.horizontal, FMSpacing.xs)
                        .padding(.vertical, FMSpacing.xxs)
                        .background(FMColors.badgeForeground.opacity(0.12), in: Capsule())

                    Spacer(minLength: 0)

                    Text(post.createdAt.relativeString)
                        .font(FMTypography.feedMeta)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Text(post.title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.brandTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: FMSpacing.sm) {
                    Label(meetingText, systemImage: "mappin.and.ellipse")
                    Label("\(post.maxMembers)명", systemImage: "person.2")
                    Label("~\(post.deadline.koreanFormatted)", systemImage: "calendar")
                }
                .font(FMTypography.feedMeta)
                .foregroundStyle(FMColors.secondaryLabel)

                HStack(spacing: FMSpacing.xs) {
                    FMUserProfileButton(
                        url: post.authorProfileURL,
                        name: post.authorName,
                        userID: post.authorID,
                        imageSize: .sm,
                        style: .compact,
                        action: onProfileTapped
                    )

                    Spacer(minLength: 0)

                    if post.commentCount > 0 {
                        Label("\(post.commentCount)", systemImage: "bubble.left")
                            .font(FMTypography.feedMeta)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        // VoiceOver: 모집 상태 → 제목 → 진행 방식 → 지역 → 인원 → 마감일 순
        .accessibilityLabel(
            "\(post.isRecruiting() ? "모집 중" : "모집 마감"), \(post.title), \(post.meetingType.displayText), \(post.region ?? "지역 무관"), \(post.maxMembers)명 모집, 마감 \(post.deadline.koreanFormatted)"
        )
        .accessibilityHint("모집 글 상세를 보려면 이중 탭하세요")
    }

    private var meetingText: String {
        if let region = post.region, !region.isEmpty {
            return "\(post.meetingType.displayText) · \(region)"
        }
        return post.meetingType.displayText
    }

    private var statusBadge: some View {
        Text(post.isRecruiting() ? "모집 중" : "모집 마감")
            .font(FMTypography.font(size: 12, relativeTo: .caption, weight: .semibold))
            .foregroundStyle(post.isRecruiting() ? FMColors.onAccent : FMColors.secondaryLabel)
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxs)
            .background(
                post.isRecruiting() ? FMColors.primaryAction : FMColors.secondaryBackground,
                in: Capsule()
            )
    }
}
