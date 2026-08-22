import SwiftUI
import ComposableArchitecture
import Core
import Domain
import Kingfisher

/// 피드의 개별 페이지 — 풀스크린 플레이어 + 정보 오버레이.
/// 탭하면 재생/일시정지, 댓글 버튼으로 피드백 시트를 연다.
public struct VideoPageView: View {
    @Bindable var store: StoreOf<VideoDetailFeature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<VideoDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            mediaBackdrop
            mediaContent

            // 일시정지 인디케이터
            if !store.player.isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: FMSizing.IconSize.xl))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 6)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            overlay
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture {
            // 시트가 열린 상태의 배경 탭은 재생 토글이 아니라 시트 닫기
            if store.showFeedbackSheet {
                store.send(.feedbackSheetDismissed)
            } else {
                store.send(.playPauseTapped)
            }
        }
        .screenCaptureGuarded()
        .onChange(of: scenePhase) { _, newPhase in
            // 백그라운드 전환 시 재생 중단 — isPlaying을 꺼둬야 복귀 후 자동 재생되지 않는다
            if newPhase == .background, store.player.isPlaying {
                store.send(.pause)
            }
        }
        .accessibilityLabel("\(store.video.uploaderName)님의 영상, \(store.video.title)")
        .accessibilityHint(store.player.isPlaying ? "탭하면 일시정지됩니다" : "탭하면 재생됩니다")
        .accessibilityAddTraits(.startsMediaSession)
        .sheet(isPresented: Binding(
            get: { store.showFeedbackSheet },
            set: { newValue in
                if !newValue { store.send(.feedbackSheetDismissed) }
            }
        )) {
            VideoFeedbackSheet(store: store)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .presentationBackground(FMColors.background)
        }
    }

    @ViewBuilder
    private var mediaBackdrop: some View {
        if let thumbnailURL = store.video.thumbnailURL {
            // scaledToFill은 제안보다 큰 사이즈를 레이아웃에 보고해 페이지 폭을 부풀리므로,
            // 레이아웃에 참여하지 않는 overlay 안에서 채운다
            Color.black
                .overlay {
                    KFImage(thumbnailURL)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.08)
                        .blur(radius: 28)
                }
                .overlay(Color.black.opacity(0.42))
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Color.black
        }
    }

    private var mediaContent: some View {
        VideoPlayerView(
            url: store.video.videoURL,
            isPlaying: store.player.isPlaying,
            seekTime: store.player.currentTime,
            isSeeking: store.player.isSeeking,
            isMuted: store.player.isMuted,
            onCurrentTimeUpdate: { store.send(.currentTimeUpdated($0)) },
            onDurationUpdate: { store.send(.durationUpdated($0)) },
            onPlaybackEnded: { store.send(.playerReachedEnd) },
            onSeekCompleted: { store.send(.seekCompleted) },
            onPausedByOtherPlayer: { store.send(.pause) }
        )
    }

    // MARK: - Overlay

    private var overlay: some View {
        VStack {
            // 피드백 완료 뱃지 — 완료해도 세션 내에서는 페이지를 유지하고 표시만 한다
            if store.hasMyFeedback {
                HStack {
                    Spacer()
                    Label("피드백 완료", systemImage: "checkmark.circle.fill")
                        .font(FMTypography.caption1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FMSpacing.sm)
                        .padding(.vertical, FMSpacing.xxs)
                        .background(FMColors.accent.opacity(0.85))
                        .clipShape(Capsule())
                        .accessibilityLabel("이 영상에 피드백을 완료했습니다")
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.sm)
            }

            Spacer()

            HStack(alignment: .bottom, spacing: FMSpacing.sm) {
                videoInfo
                Spacer(minLength: FMSpacing.md)
                actionRail
            }
            .padding(.horizontal, FMSpacing.md)

            seekBar
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.md)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .allowsHitTesting(false)
        }
    }

    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            HStack(spacing: FMSpacing.xs) {
                Text(store.video.uploaderName)
                    .font(FMTypography.headline)
                    .foregroundStyle(.white)

                FMVerifiedBadge(userID: store.video.uploaderID)

                Text(store.video.createdAt.relativeString)
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(store.video.title)
                .font(FMTypography.body)
                .foregroundStyle(.white)
                .lineLimit(2)

            if let focusPoints = store.video.focusPoints {
                Label(focusPoints, systemImage: "video.fill")
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .accessibilityLabel("촬영 포인트: \(focusPoints)")
            }

            if let feedbackRequest = store.video.feedbackRequest {
                Label(feedbackRequest, systemImage: "text.bubble")
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .accessibilityLabel("피드백 요청: \(feedbackRequest)")
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }

    private var actionRail: some View {
        VStack(spacing: FMSpacing.lg) {
            playerActionButton(
                systemImage: feedbackCount > 0 ? "bubble.left.fill" : "bubble.left",
                badgeText: feedbackCount > 0 ? "\(feedbackCount)" : nil
            ) {
                store.send(.feedbackSheetTapped)
            }
            .accessibilityLabel("피드백 \(feedbackCount)개 보기")
            .accessibilityHint("촬영 포인트와 피드백 목록이 열립니다")

            playerActionButton(
                systemImage: store.player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
            ) {
                store.send(.muteTapped)
            }
            .accessibilityLabel(store.player.isMuted ? "음소거 해제" : "음소거")
        }
    }

    private func playerActionButton(
        systemImage: String,
        badgeText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: FMSizing.IconSize.md, weight: .semibold))
                .foregroundStyle(FMColors.accent)
                .frame(width: 48, height: 48)
                .background(playerControlSurface, in: Circle())
                .overlay {
                    Circle()
                        .stroke(playerControlBorder, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if let badgeText {
                        Text(badgeText)
                            .font(FMTypography.caption1)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(FMColors.mediaBadgeForeground)
                            .padding(.horizontal, FMSpacing.xxs)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(.white, in: Capsule())
                            .offset(x: 5, y: -4)
                    }
                }
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    private var seekBar: some View {
        VStack(spacing: FMSpacing.xxxs) {
            Slider(
                value: Binding(
                    get: { store.player.currentTime },
                    set: { store.send(.seek(to: $0)) }
                ),
                in: 0...max(store.player.duration, 1)
            )
            .tint(FMColors.accent)
            .controlSize(.small)
            .accessibilityLabel("재생 위치")
            .accessibilityValue(
                "\(store.player.currentTime.minuteSecondFormatted) / \(store.player.duration.minuteSecondFormatted)"
            )

            HStack {
                Text(store.player.currentTime.minuteSecondFormatted)
                    .foregroundStyle(FMColors.accent)

                Spacer()

                Text(store.player.duration.minuteSecondFormatted)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .font(FMTypography.caption2)
            .monospacedDigit()
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private var playerControlSurface: Color {
        .black.opacity(0.56)
    }

    private var playerControlBorder: Color {
        FMColors.accent.opacity(0.42)
    }

    private var feedbackCount: Int {
        if case .loaded(let feedbacks) = store.feedbacks {
            return feedbacks.count
        }
        return store.video.feedbackCount
    }
}
