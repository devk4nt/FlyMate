import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackManagementView: View {
    private enum Constants {
        static let quickFeedbackPreviewCount = 3
    }

    @Bindable var store: StoreOf<FeedbackManagementFeature>

    public init(store: StoreOf<FeedbackManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                // 헤더+세그먼트를 각 자식의 ScrollView 콘텐츠로 주입 —
                // pull-to-refresh가 탭 최상단에서 동작 (스터디/모집 탭과 일관성)
                switch store.selectedSegment {
                case .pending:
                    VideoFeedView(
                        store: store.scope(state: \.pending, action: \.pending)
                    ) {
                        tabHeader
                    }
                case .received:
                    FeedbackListView(
                        store: store.scope(state: \.received, action: \.received),
                        sectionTitle: "스터디 피드백"
                    ) {
                        receivedHeader
                    }
                case .given:
                    FeedbackListView(
                        store: store.scope(state: \.given, action: \.given)
                    ) {
                        tabHeader
                    }
                }
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .background(FMColors.canvas)
            .navigationTitle("피드백")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $store.scope(state: \.quickFeedbackDetail, action: \.quickFeedbackDetail)) { detailStore in
            NavigationStack { QuickFeedbackRequestDetailView(store: detailStore) }
        }
        .background(FMColors.canvas)
    }

    private var tabHeader: some View {
        VStack(spacing: 0) {
            feedbackHeader
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xxs)

            segmentControl
                .padding(.horizontal, FMSpacing.md)
                .padding(.vertical, FMSpacing.sm)
        }
    }

    private var receivedHeader: some View {
        VStack(spacing: FMSpacing.md) {
            tabHeader
            quickFeedbackSection
                .padding(.horizontal, FMSpacing.md)
        }
    }

    @ViewBuilder
    private var quickFeedbackSection: some View {
        switch store.quickFeedback {
        case .idle, .loading:
            quickFeedbackSkeleton

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.segmentChanged(.received))
            }

        case .loaded(let dashboard):
            let requests = dashboard.myRequests.filter {
                !dashboard.reviews(for: $0.id).isEmpty
            }
            if !requests.isEmpty {
                VStack(alignment: .leading, spacing: FMSpacing.sm) {
                    HStack(spacing: FMSpacing.xs) {
                        Text("빠른 피드백")
                            .font(FMTypography.sectionTitle)
                            .foregroundStyle(FMColors.brandTitle)

                        sectionCountBadge(requests.count)

                        Spacer()

                        if requests.count > Constants.quickFeedbackPreviewCount {
                            NavigationLink {
                                QuickFeedbackHistoryListView(
                                    dashboard: dashboard,
                                    onRequestTapped: {
                                        store.send(.quickFeedbackRequestTapped($0))
                                    }
                                )
                            } label: {
                                Text("전체 보기")
                                    .font(FMTypography.authorName)
                            }
                            .accessibilityLabel("빠른 피드백 요청 \(requests.count)개 전체 보기")
                            .accessibilityHint("빠른 피드백 요청 전체 목록으로 이동합니다")
                        }
                    }

                    ForEach(Array(requests.prefix(Constants.quickFeedbackPreviewCount))) { request in
                        Button {
                            store.send(.quickFeedbackRequestTapped(request.id))
                        } label: {
                            FMCard(style: .feed) {
                                HStack(spacing: FMSpacing.sm) {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.title2)
                                        .foregroundStyle(FMColors.iconAccent)
                                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                                        Text(request.title)
                                            .font(FMTypography.authorName)
                                            .foregroundStyle(FMColors.brandTitle)
                                        Text("받은 답변 \(dashboard.reviews(for: request.id).count)개")
                                            .font(FMTypography.caption1)
                                            .foregroundStyle(FMColors.secondaryLabel)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(FMTypography.caption1)
                                        .foregroundStyle(FMColors.secondaryLabel)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("업로드한 영상과 받은 빠른 피드백을 확인합니다")
                    }
                }
            }
        }
    }

    private var quickFeedbackSkeleton: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            HStack(spacing: FMSpacing.xs) {
                FMSkeletonView(
                    width: 88,
                    height: 20,
                    isShimmering: false
                )
                FMSkeletonView(
                    width: 28,
                    height: 20,
                    cornerRadius: 10,
                    isShimmering: false
                )
            }

            FMCard(style: .feed) {
                HStack(spacing: FMSpacing.sm) {
                    FMSkeletonView(
                        width: 28,
                        height: 24,
                        cornerRadius: FMSpacing.CornerRadius.sm,
                        isShimmering: false
                    )

                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        FMSkeletonView(
                            width: 144,
                            height: 16,
                            isShimmering: false
                        )
                        FMSkeletonView(
                            width: 80,
                            height: 12,
                            isShimmering: false
                        )
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("빠른 피드백 로딩 중")
    }

    private func sectionCountBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(FMTypography.caption1.weight(.semibold))
            .foregroundStyle(FMColors.actionForeground)
            .monospacedDigit()
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxxs)
            .background(FMColors.accent.opacity(0.1), in: Capsule())
            .accessibilityLabel("\(count)개 요청")
    }

    private var feedbackHeader: some View {
        HStack(spacing: FMSpacing.sm) {
            FMPracticeSymbol(size: 44)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("함께 만드는 피드백")
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.secondaryLabel)

                Text("한마디가 다음 영상을 바꿔요")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.brandTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(FeedbackManagementFeature.State.Segment.allCases, id: \.self) { segment in
                Button {
                    store.send(.segmentChanged(segment), animation: .snappy)
                } label: {
                    HStack(spacing: FMSpacing.xxs) {
                        Text(segment.rawValue)
                            .font(FMTypography.authorName)
                            .foregroundStyle(
                                store.selectedSegment == segment
                                    ? FMColors.selection
                                    : FMColors.secondaryLabel
                            )

                        if segment == .pending {
                            FMBadge(count: pendingCount)
                                .accessibilityLabel("피드백할 영상 \(pendingCount)개")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background {
                        if store.selectedSegment == segment {
                            Capsule()
                                .fill(FMColors.background)
                                .shadow(
                                    color: FMShadow.floatingColor,
                                    radius: FMShadow.floatingRadius,
                                    y: FMShadow.floatingY
                                )
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.selectedSegment == segment ? .isSelected : [])
            }
        }
        .padding(4)
        .background(FMColors.supportAccent.opacity(0.12), in: Capsule())
    }

    private var pendingCount: Int {
        guard case .loaded(let videos) = store.pending.loadingState else { return 0 }
        return videos.count
    }

    private func segmentIcon(for segment: FeedbackManagementFeature.State.Segment) -> String {
        switch segment {
        case .pending:
            "play.rectangle.on.rectangle.fill"
        case .received:
            "tray.and.arrow.down.fill"
        case .given:
            "paperplane.fill"
        }
    }
}

private struct QuickFeedbackHistoryListView: View {
    let dashboard: QuickFeedbackDashboard
    let onRequestTapped: (UUID) -> Void

    private var requests: [QuickFeedbackRequest] {
        dashboard.myRequests.filter {
            !dashboard.reviews(for: $0.id).isEmpty
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                ForEach(requests) { request in
                    Button { onRequestTapped(request.id) } label: {
                        FMCard(style: .feed) {
                            HStack(spacing: FMSpacing.sm) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(FMColors.iconAccent)
                                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                                    Text(request.title)
                                        .font(FMTypography.authorName)
                                        .foregroundStyle(FMColors.label)
                                    Text("받은 답변 \(dashboard.reviews(for: request.id).count)개")
                                        .font(FMTypography.caption1)
                                        .foregroundStyle(FMColors.secondaryLabel)
                                    Text(request.createdAt.relativeString)
                                        .font(FMTypography.caption1)
                                        .foregroundStyle(FMColors.secondaryLabel)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(FMTypography.caption1)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("업로드한 영상과 받은 빠른 피드백을 확인합니다")
                }
            }
            .padding(FMSpacing.md)
        }
        .background(FMColors.canvas)
        .navigationTitle("빠른 피드백 전체")
        .navigationBarTitleDisplayMode(.inline)
    }
}
