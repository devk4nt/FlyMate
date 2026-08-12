import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct VideoFeedView: View {
    @Bindable var store: StoreOf<VideoFeedFeature>

    public init(store: StoreOf<VideoFeedFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.feedScope {
            case .pendingFeedback:
                queueNavigation
            case .study:
                immersiveFeed
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.viewDisappeared) }
    }

    // MARK: - Feedback Queue

    private var queueNavigation: some View {
        NavigationStack {
            queueContent
                .navigationTitle("피드")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(
                    item: Binding(
                        get: { store.presentedVideoID },
                        set: { newValue in
                            if newValue == nil {
                                store.send(.playerDismissed)
                            }
                        }
                    )
                ) { _ in
                    immersiveFeed
                        .toolbar(.hidden, for: .tabBar)
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        Group {
            switch store.loadingState {
            case .idle, .loading:
                loadingQueue

            case .loaded(let videos):
                if videos.isEmpty {
                    emptyQueue
                } else {
                    loadedQueue(videos)
                }

            case .failed(let error):
                failedQueue(error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.softCanvas.ignoresSafeArea())
    }

    private var loadingQueue: some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                queueHeader(count: nil)

                ForEach(0..<3, id: \.self) { _ in
                    FMSkeletonView.card
                }
                .padding(.horizontal, FMSpacing.md)
            }
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
    }

    private func loadedQueue(_ videos: [Video]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                queueHeader(count: videos.count)
                    .padding(.bottom, FMSpacing.sm)

                ForEach(videos) { video in
                    Button {
                        store.send(.videoTapped(video.id))
                    } label: {
                        FMFeedCell(
                            authorName: video.uploaderName,
                            timeText: video.createdAt.relativeString,
                            thumbnailURL: video.thumbnailURL,
                            durationText: video.durationSeconds.minuteSecondFormatted,
                            title: video.title,
                            feedbackCount: video.feedbackCount
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("영상을 재생하고 피드백을 남기려면 이중 탭하세요")
                }
            }
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .refreshable {
            await store.send(.retryTapped).finish()
        }
    }

    private var emptyQueue: some View {
        ScrollView {
            VStack(spacing: FMSpacing.md) {
                queueHeader(count: 0)

                VStack(spacing: FMSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: FMSizing.IconSize.hero, weight: .medium))
                        .foregroundStyle(FMColors.success)
                        .frame(width: 72, height: 72)
                        .background(FMColors.success.opacity(0.12), in: Circle())

                    VStack(spacing: FMSpacing.xs) {
                        Text("모든 피드백을 완료했어요")
                            .font(.headline)
                            .foregroundStyle(FMColors.label)

                        Text("스터디원이 새 영상을 올리면 여기에 표시됩니다.")
                            .font(.subheadline)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FMSpacing.lg)
                .padding(.vertical, FMSpacing.xxl)
                .background(
                    FMColors.background,
                    in: RoundedRectangle(
                        cornerRadius: FMSpacing.CornerRadius.xl,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: FMSpacing.CornerRadius.xl,
                        style: .continuous
                    )
                    .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
                }
                .padding(.horizontal, FMSpacing.md)
            }
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .refreshable {
            await store.send(.retryTapped).finish()
        }
    }

    private func failedQueue(_ error: AppError) -> some View {
        ScrollView {
            VStack(spacing: FMSpacing.md) {
                queueHeader(count: nil)

                FMErrorView(error: error) {
                    store.send(.retryTapped)
                }
                .frame(minHeight: 320)
                .background(
                    FMColors.background,
                    in: RoundedRectangle(
                        cornerRadius: FMSpacing.CornerRadius.xl,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: FMSpacing.CornerRadius.xl,
                        style: .continuous
                    )
                    .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
                }
                .padding(.horizontal, FMSpacing.md)
            }
            .padding(.top, FMSpacing.xs)
            .padding(.bottom, FMSpacing.xxxl)
        }
    }

    private func queueHeader(count: Int?) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(FMColors.brandGradient, in: Circle())
                .shadow(color: FMColors.brandInk.opacity(0.14), radius: 7, y: 4)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("PRACTICE TOGETHER")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(FMColors.brandInk)

                Text(count.map { "피드백할 영상 \($0)개" } ?? "피드백할 영상을 확인해요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.label)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
        .background(
            FMColors.background,
            in: RoundedRectangle(
                cornerRadius: FMSpacing.CornerRadius.lg,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: FMSpacing.CornerRadius.lg,
                style: .continuous
            )
            .stroke(FMColors.accent.opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, FMSpacing.md)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Immersive Player

    private var immersiveFeed: some View {
        Group {
            switch store.loadingState {
            case .idle, .loading:
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let videos):
                if videos.isEmpty {
                    immersiveEmptyState
                } else {
                    pagingFeed
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.retryTapped)
                }
                .colorScheme(.dark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var pagingFeed: some View {
        // safe area가 스크롤 범위에 끼면 페이지 높이와 스와이프 거리가 어긋나
        // 마지막 페이지가 이전 페이지 하단을 물고 멈춘다 — 스크롤 영역은 풀스크린으로 잡고
        // 각 페이지 안에서 inset을 safeAreaPadding으로 복원한다
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(store.scope(state: \.pages, action: \.pages)) { pageStore in
                        VideoPageView(store: pageStore)
                            .safeAreaPadding(proxy.safeAreaInsets)
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(
                id: Binding(
                    get: { store.currentVideoID },
                    set: { store.send(.currentVideoChanged($0)) }
                )
            )
            .scrollIndicators(.hidden)
            .refreshable {
                await store.send(.retryTapped).finish()
            }
            .ignoresSafeArea()
            .accessibilityLabel("영상 피드")
            .accessibilityHint("위아래로 스와이프하여 영상을 넘길 수 있습니다")
        }
    }

    // MARK: - Empty State

    private var immersiveEmptyState: some View {
        ScrollView {
            Group {
                if case .pendingFeedback = store.feedScope {
                    FMEmptyState(
                        systemImage: "checkmark.circle",
                        title: "모든 피드백을 완료했어요",
                        description: "스터디원이 새 영상을 올리면 여기에 표시됩니다"
                    )
                } else {
                    FMEmptyState(
                        systemImage: "video.slash",
                        title: "아직 영상이 없습니다",
                        description: "스터디에 첫 영상을 올리고 피드백을 받아보세요"
                    )
                }
            }
            .colorScheme(.dark)
            .containerRelativeFrame([.horizontal, .vertical])
        }
        .refreshable {
            await store.send(.retryTapped).finish()
        }
    }
}
