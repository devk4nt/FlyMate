import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct VideoDetailView: View {
    @Bindable var store: StoreOf<VideoDetailFeature>
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?

    private static let controlsAutoHideSeconds: UInt64 = 3

    public init(store: StoreOf<VideoDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 영상 플레이어 + 오버레이 컨트롤
            videoPlayerWithControls

            // 촬영 포인트 & 피드백 요청
            videoInfoSection

            // 피드백 목록
            feedbackSection
        }
        .navigationTitle(store.video.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.writeFeedbackTapped)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
            scheduleHideControls()
        }
        .onDisappear {
            hideControlsTask?.cancel()
            store.send(.onDisappear)
        }
        .sheet(item: $store.scope(state: \.feedbackWrite, action: \.feedbackWrite)) { writeStore in
            NavigationStack {
                FeedbackWriteView(store: writeStore)
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.player.isFullscreen },
            set: { newValue in
                if !newValue { store.send(.dismissFullscreen) }
            }
        )) {
            FullscreenVideoView(store: store)
        }
    }

    // MARK: - Video Player with Overlay Controls

    private var videoPlayerWithControls: some View {
        ZStack {
            VideoPlayerView(
                url: store.video.videoURL,
                isPlaying: store.player.isPlaying,
                seekTime: store.player.currentTime,
                isSeeking: store.player.isSeeking,
                isMuted: store.player.isMuted,
                onCurrentTimeUpdate: { time in
                    store.send(.currentTimeUpdated(time))
                },
                onDurationUpdate: { duration in
                    store.send(.durationUpdated(duration))
                },
                onPlaybackEnded: {
                    store.send(.playerReachedEnd)
                    showControlsWithAutoHide()
                },
                onSeekCompleted: {
                    store.send(.seekCompleted)
                }
            )

            // 컨트롤 오버레이
            if showControls {
                playerControlsOverlay
                    .transition(.opacity)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black, ignoresSafeAreaEdges: [])
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .accessibilityLabel("영상 플레이어")
        .accessibilityAddTraits(.startsMediaSession)
    }

    private var playerControlsOverlay: some View {
        ZStack {
            // 반투명 그라데이션 배경
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }

            // 중앙 재생/일시정지 버튼
            Button {
                store.send(.playPauseTapped)
                scheduleHideControls()
            } label: {
                Image(systemName: store.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .accessibilityLabel(store.player.isPlaying ? "일시정지" : "재생")

            // 하단 컨트롤 바
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: FMSpacing.xxs) {
                    // 시크바
                    Slider(
                        value: Binding(
                            get: { store.player.currentTime },
                            set: {
                                store.send(.seek(to: $0))
                                scheduleHideControls()
                            }
                        ),
                        in: 0...max(store.player.duration, 1)
                    )
                    .tint(.white)

                    // 시간 + 음소거 + 전체화면
                    HStack(spacing: FMSpacing.sm) {
                        Text(store.player.currentTime.minuteSecondFormatted)
                            .font(FMTypography.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .monospacedDigit()

                        Text("/")
                            .font(FMTypography.caption2)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(store.player.duration.minuteSecondFormatted)
                            .font(FMTypography.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .monospacedDigit()

                        Spacer()

                        Button {
                            store.send(.muteTapped)
                            scheduleHideControls()
                        } label: {
                            Image(systemName: store.player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .accessibilityLabel(store.player.isMuted ? "음소거 해제" : "음소거")

                        Button {
                            store.send(.fullscreenTapped)
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .accessibilityLabel("전체화면")
                    }
                }
                .padding(.horizontal, FMSpacing.sm)
                .padding(.bottom, FMSpacing.xs)
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Controls Visibility

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showControls.toggle()
        }
        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private func showControlsWithAutoHide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showControls = true
        }
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.controlsAutoHideSeconds))
            guard !Task.isCancelled else { return }
            guard store.player.isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showControls = false
            }
        }
    }

    // MARK: - Video Info

    @ViewBuilder
    private var videoInfoSection: some View {
        let hasInfo = store.video.focusPoints != nil || store.video.feedbackRequest != nil
        if hasInfo {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                if let focusPoints = store.video.focusPoints {
                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        Label("촬영 포인트", systemImage: "video.fill")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text(focusPoints)
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.label)
                    }
                }

                if let feedbackRequest = store.video.feedbackRequest {
                    VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                        Label("피드백 요청", systemImage: "text.bubble")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                        Text(feedbackRequest)
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.label)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FMSpacing.md)
            .background(FMColors.secondaryBackground)
        }
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        Group {
            switch store.feedbacks {
            case .idle, .loading:
                VStack {
                    ForEach(0..<3, id: \.self) { _ in
                        FMSkeletonView()
                            .frame(height: 60)
                    }
                }
                .padding(FMSpacing.md)

            case .loaded(let feedbacks):
                if feedbacks.isEmpty {
                    FMEmptyState(
                        systemImage: "bubble.left",
                        title: "아직 피드백이 없습니다",
                        description: "첫 번째 피드백을 남겨보세요."
                    ) {
                        store.send(.writeFeedbackTapped)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: FMSpacing.xs) {
                                ForEach(feedbacks) { feedback in
                                    FeedbackRow(
                                        feedback: feedback,
                                        isHighlighted: store.focusedFeedbackID == feedback.id,
                                        onTimestampTapped: {
                                            store.send(.feedbackTapped(feedback))
                                        }
                                    )
                                    .id(feedback.id)
                                }
                            }
                            .padding(FMSpacing.md)
                        }
                        .onChange(of: store.focusedFeedbackID) { _, focusedID in
                            if let focusedID {
                                withAnimation {
                                    proxy.scrollTo(focusedID, anchor: .center)
                                }
                            }
                        }
                        .onAppear {
                            if let focusedID = store.focusedFeedbackID {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation {
                                        proxy.scrollTo(focusedID, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {}
            }
        }
    }
}

// MARK: - Feedback Row

private struct FeedbackRow: View {
    let feedback: Domain.Feedback
    var isHighlighted: Bool = false
    var onTimestampTapped: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            // 타임스탬프 뱃지
            Text(feedback.timestampSeconds.minuteSecondFormatted)
                .font(FMTypography.caption1)
                .padding(.horizontal, FMSpacing.xs)
                .padding(.vertical, FMSpacing.xxxs)
                .background(FMColors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
                .onTapGesture {
                    onTimestampTapped?()
                }

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                HStack {
                    Text(feedback.authorName)
                        .font(FMTypography.caption1)
                        .fontWeight(.semibold)
                    Text(feedback.createdAt.relativeString)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                Text(feedback.content)
                    .font(FMTypography.callout)
            }

            Spacer(minLength: 0)
        }
        .padding(FMSpacing.sm)
        .background(
            isHighlighted
                ? FMColors.accent.opacity(0.15)
                : FMColors.secondaryBackground
        )
        .animation(.easeInOut(duration: 0.6), value: isHighlighted)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
    }
}

// MARK: - Fullscreen Video

private struct FullscreenVideoView: View {
    @Bindable var store: StoreOf<VideoDetailFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?

    private static let controlsAutoHideSeconds: UInt64 = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayerView(
                url: store.video.videoURL,
                isPlaying: store.player.isPlaying,
                seekTime: store.player.currentTime,
                isSeeking: store.player.isSeeking,
                isMuted: store.player.isMuted,
                onCurrentTimeUpdate: { time in
                    store.send(.currentTimeUpdated(time))
                },
                onDurationUpdate: { duration in
                    store.send(.durationUpdated(duration))
                },
                onPlaybackEnded: {
                    store.send(.playerReachedEnd)
                    showControlsWithAutoHide()
                },
                onSeekCompleted: {
                    store.send(.seekCompleted)
                }
            )
            .ignoresSafeArea()

            // 오버레이 컨트롤
            if showControls {
                fullscreenControlsOverlay
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleControls() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { scheduleHideControls() }
        .onDisappear { hideControlsTask?.cancel() }
    }

    // MARK: - Controls Overlay

    private var fullscreenControlsOverlay: some View {
        ZStack {
            // 상단 + 하단 그라데이션
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
            }
            .ignoresSafeArea()

            // 중앙 재생/일시정지
            Button {
                store.send(.playPauseTapped)
                scheduleHideControls()
            } label: {
                Image(systemName: store.player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(store.player.isPlaying ? "일시정지" : "재생")

            // 상단: 닫기(좌) + 음소거(우)
            VStack {
                HStack {
                    Button {
                        store.send(.dismissFullscreen)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("전체화면 닫기")

                    Spacer()

                    Button {
                        store.send(.muteTapped)
                        scheduleHideControls()
                    } label: {
                        Image(systemName: store.player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(store.player.isMuted ? "음소거 해제" : "음소거")
                }
                .padding(.horizontal, FMSpacing.sm)

                Spacer()
            }

            // 하단: 시크바 + 시간
            VStack {
                Spacer()

                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { store.player.currentTime },
                            set: {
                                store.send(.seek(to: $0))
                                scheduleHideControls()
                            }
                        ),
                        in: 0...max(store.player.duration, 1)
                    )
                    .tint(.white)

                    HStack {
                        Text(store.player.currentTime.minuteSecondFormatted)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .monospacedDigit()
                        Spacer()
                        Text(store.player.duration.minuteSecondFormatted)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.bottom, FMSpacing.md)
            }
        }
    }

    // MARK: - Controls Visibility

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showControls.toggle()
        }
        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private func showControlsWithAutoHide() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showControls = true
        }
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.controlsAutoHideSeconds))
            guard !Task.isCancelled else { return }
            guard store.player.isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                showControls = false
            }
        }
    }
}
