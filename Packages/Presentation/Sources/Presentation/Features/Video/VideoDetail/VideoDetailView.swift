import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct VideoDetailView: View {
    @Bindable var store: StoreOf<VideoDetailFeature>

    public init(store: StoreOf<VideoDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 영상 플레이어 영역
            videoPlayerArea

            // 플레이어 컨트롤
            playerControls

            // 촬영 포인트 & 피드백 요청
            videoInfoSection

            // 피드백 목록
            feedbackSection
        }
        .navigationTitle(store.video.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.writeFeedbackTapped)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .sheet(item: $store.scope(state: \.feedbackWrite, action: \.feedbackWrite)) { writeStore in
            NavigationStack {
                FeedbackWriteView(store: writeStore)
            }
            .presentationDetents([.medium])
        }
    }

    private var videoPlayerArea: some View {
        VideoPlayerView(
            url: store.video.videoURL,
            isPlaying: store.player.isPlaying,
            seekTime: store.player.currentTime,
            isSeeking: store.player.isSeeking,
            onCurrentTimeUpdate: { time in
                store.send(.currentTimeUpdated(time))
            },
            onDurationUpdate: { duration in
                store.send(.durationUpdated(duration))
            },
            onPlaybackEnded: {
                store.send(.playerReachedEnd)
            },
            onSeekCompleted: {
                store.send(.seekCompleted)
            }
        )
        .aspectRatio(16 / 9, contentMode: .fit)
        .background(Color.black)
        .accessibilityLabel("영상 플레이어")
        .accessibilityAddTraits(.startsMediaSession)
    }

    private var playerControls: some View {
        VStack(spacing: FMSpacing.xxs) {
            // 시크바
            Slider(
                value: Binding(
                    get: { store.player.currentTime },
                    set: { store.send(.seek(to: $0)) }
                ),
                in: 0...max(store.player.duration, 1)
            )
            .tint(FMColors.accent)

            // 재생 버튼 + 시간 표시
            HStack {
                Button {
                    store.send(.playPauseTapped)
                } label: {
                    Image(systemName: store.player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(FMColors.label)
                }
                .accessibilityLabel(store.player.isPlaying ? "일시정지" : "재생")

                Text(store.player.currentTime.minuteSecondFormatted)
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .monospacedDigit()

                Spacer()

                Text(store.player.duration.minuteSecondFormatted)
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.xs)
    }

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
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.xs) {
                            ForEach(feedbacks) { feedback in
                                FeedbackRow(feedback: feedback)
                                    .onTapGesture {
                                        store.send(.feedbackTapped(feedback))
                                    }
                            }
                        }
                        .padding(FMSpacing.md)
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

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            // 타임스탬프 뱃지
            Text(feedback.timestampSeconds.minuteSecondFormatted)
                .font(FMTypography.caption1)
                .padding(.horizontal, FMSpacing.xs)
                .padding(.vertical, FMSpacing.xxxs)
                .background(FMColors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

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
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
    }
}
