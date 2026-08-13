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
                // 시트가 열린 채 시스템 back으로 pop되면 스택 요소 제거 후 캐시된 상태로
                // 시트가 뒤늦게 사라진다 — 시트가 열린 동안만 back을 가로채
                // "시트 닫기 → pop" 순서를 보장한다 (닫혀 있을 땐 시스템 back/스와이프 유지)
                immersiveFeed
                    .navigationBarBackButtonHidden(isFeedbackSheetOpen)
                    .toolbar {
                        if isFeedbackSheetOpen {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    store.send(.backTapped)
                                } label: {
                                    Image(systemName: "chevron.backward")
                                }
                                .accessibilityLabel("뒤로 가기")
                            }
                        }
                    }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.viewDisappeared) }
    }

    private var isFeedbackSheetOpen: Bool {
        guard let currentID = store.currentVideoID else { return false }
        return store.pages[id: currentID]?.showFeedbackSheet == true
    }

    // MARK: - Feedback Queue

    // 부모(FeedbackManagementView)의 NavigationStack에 destination을 붙인다
    private var queueNavigation: some View {
        queueContent
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
            FMEmptyState(
                systemImage: "checkmark.circle.fill",
                title: "모든 피드백을 완료했어요",
                description: "스터디원이 새 영상을 올리면 여기에 표시됩니다.",
                layout: .card,
                tint: FMColors.success
            )
            .padding(.horizontal, FMSpacing.md)
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
                            // scrollPosition이 정착 지점의 페이지를 UUID로 식별할 수 있도록 명시
                            .id(pageStore.video.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            // 수동 Binding(get:set:)은 observation에 참여하지 않아 스크롤 정착 시
            // set이 호출되지 않을 수 있다 — 관찰 가능한 바인딩으로 페이지 전환을 전달한다
            .scrollPosition(id: $store.currentVideoID.sending(\.currentVideoChanged))
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
