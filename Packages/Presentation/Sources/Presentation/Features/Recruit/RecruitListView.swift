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
                .background(FMColors.softCanvas)
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
                            RecruitPostRow(post: post)
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
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxxl)
            }
            .refreshable {
                store.send(.refresh)
            }

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.refresh)
            }
        }
    }

    // MARK: - Hero

    private var recruitmentHero: some View {
        VStack(alignment: .leading, spacing: FMSpacing.lg) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Label("STUDY TOGETHER", systemImage: "person.3.fill")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(FMColors.onBrand)

                Text("함께 연습할 동료를 찾아보세요")
                    .font(FMTypography.sectionTitle)
                    .foregroundStyle(.white)

                Text("진행 방식과 일정이 맞는 스터디를 찾거나\n직접 모집 글을 올려보세요.")
                    .font(.subheadline)
                    .foregroundStyle(FMColors.onBrand)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                store.send(.createTapped)
            } label: {
                Label("모집 글 작성", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.brandInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
            .accessibilityHint("새 스터디원 모집 글을 작성합니다")
            .accessibilityIdentifier("스터디_목록_히어로_모집글작성")
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
                    .offset(x: -30, y: 138)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .shadow(color: FMColors.brandInk.opacity(0.2), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Filter

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            Text("모집 글")
                .font(FMTypography.sectionTitle)
                .foregroundStyle(FMColors.label)

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
                .font(.caption2)
        }
        .font(FMTypography.feedMetaEmphasis)
        .foregroundStyle(isActive ? FMColors.onAccent : FMColors.label)
        .padding(.horizontal, FMSpacing.sm)
        .padding(.vertical, FMSpacing.xs)
        .background(isActive ? FMColors.accentFill : FMColors.background, in: Capsule())
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
            .background(isActive ? FMColors.accentFill : FMColors.background, in: Capsule())
            .overlay {
                Capsule().stroke(FMColors.border.opacity(0.4), lineWidth: isActive ? 0 : 1)
            }
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: FMSpacing.md) {
            Image(systemName: "megaphone")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(FMColors.brandInk)
                .frame(width: 72, height: 72)
                .background(FMColors.accent.opacity(0.12), in: Circle())

            VStack(spacing: FMSpacing.xs) {
                Text("아직 모집 글이 없어요")
                    .font(.headline)
                    .foregroundStyle(FMColors.label)

                Text("첫 번째로 스터디원을 모집해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMSpacing.xxl)
        .padding(.horizontal, FMSpacing.lg)
        .background(
            FMColors.background,
            in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Row

struct RecruitPostRow: View {
    let post: RecruitPost

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            HStack(spacing: FMSpacing.xs) {
                statusBadge

                Text(post.field.displayText)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.brandInk)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxs)
                    .background(FMColors.accent.opacity(0.12), in: Capsule())

                Spacer(minLength: 0)

                Text(post.createdAt.relativeString)
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            Text(post.title)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)
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
                Text(post.authorName)
                    .font(FMTypography.feedMeta)
                    .foregroundStyle(FMColors.secondaryLabel)

                Spacer(minLength: 0)

                if post.commentCount > 0 {
                    Label("\(post.commentCount)", systemImage: "bubble.left")
                        .font(FMTypography.feedMeta)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
            }
        }
        .padding(FMSpacing.lg)
        .background(post.isRecruiting() ? FMColors.background : FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.xl, style: .continuous)
                .stroke(
                    post.isRecruiting() ? FMColors.accent.opacity(0.2) : FMColors.border,
                    lineWidth: 1
                )
        }
        .shadow(color: FMColors.brandInk.opacity(0.07), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
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
            .font(FMTypography.caption1.weight(.semibold))
            .foregroundStyle(post.isRecruiting() ? FMColors.onAccent : FMColors.secondaryLabel)
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxs)
            .background(
                post.isRecruiting() ? FMColors.accentFill : FMColors.secondaryBackground,
                in: Capsule()
            )
    }
}
