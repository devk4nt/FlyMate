import SwiftUI
import ARKit
import StoreKit
import ComposableArchitecture
import Core

public struct PracticeMirrorView: View {
    @Bindable var store: StoreOf<PracticeMirrorFeature>
    @State private var shareImage: Image?
    @Environment(\.requestReview) private var requestReview

    public init(store: StoreOf<PracticeMirrorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            if ARFaceTrackingConfiguration.isSupported {
                SmileMirrorView { score in
                    Task { @MainActor in
                        store.send(.smileSampled(score))
                    }
                }
                // ARSCNView 프리뷰 원본은 비반전(면접관 시점) — 거울 모드에서만 뒤집는다.
                .scaleEffect(x: store.isMirrored ? -1 : 1, y: 1)
                .ignoresSafeArea()
            } else if isDemoMode {
                demoBackdrop
            } else {
                unsupportedView
            }

            VStack {
                ZStack {
                    HStack {
                        mirrorToggleButton
                        Spacer()
                        closeButton
                    }

                    if store.phase == .measuring {
                        timerBadge
                    }
                }
                .padding(FMSpacing.md)

                Spacer()

                if ARFaceTrackingConfiguration.isSupported || isDemoMode {
                    bottomOverlay
                        .padding(.horizontal, FMSpacing.md)
                        .padding(.bottom, FMSpacing.lg)
                }
            }
        }
        .background(Color.black)
        // preferredColorScheme은 앱 전체 스킴을 바꿔 표시/해제 시 플리커를 유발한다 — 뷰 스코프로 한정
        .environment(\.colorScheme, .dark)
        .onChange(of: store.isReviewPromptRequested) { _, isRequested in
            if isRequested {
                requestReview()
            }
        }
    }

    /// 시뮬레이터 데모 — ARKit 미지원 환경(DEBUG)에서 합성 미소 값으로 전체 플로우를 확인한다.
    /// 실기기는 항상 isSupported=true라 이 경로를 타지 않는다.
    private var isDemoMode: Bool {
        #if DEBUG
        return !ARFaceTrackingConfiguration.isSupported
        #else
        return false
        #endif
    }

    #if DEBUG
    private var demoBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.12, blue: 0.20), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            Text(store.isSmiling ? "😄" : "🙂")
                .font(.system(size: 160))
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .task(id: store.phase) {
            guard store.phase == .measuring else { return }
            var time = 0.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(25)) // 4배속 — 긴 그래프를 빠르게 채운다
                time += 0.1
                let score = min(1, max(0, 0.55 + 0.25 * sin(time / 3) + Double.random(in: -0.05...0.05)))
                store.send(.smileSampled(score))
            }
        }
    }
    #endif

    // MARK: - Phase Overlay

    @ViewBuilder
    private var bottomOverlay: some View {
        switch store.phase {
        case .ready:
            readyCard
        case .measuring:
            measuringCard
        case .finished:
            reportCard
        }
    }

    private var readyCard: some View {
        VStack(spacing: FMSpacing.md) {
            VStack(spacing: FMSpacing.xxs) {
                Text("얼굴을 화면에 맞추고 시작을 눌러주세요")
                    .font(FMTypography.title1)
                    .foregroundStyle(.white)

                Text(
                    store.isShortSessionNoticeVisible
                        ? "리포트는 \(Int(AppConstants.PracticeMirror.minimumReportDuration))초 이상 연습했을 때 만들어져요"
                        : "측정 중 미소 강도와 유지율을 기록해 리포트로 보여드려요"
                )
                .font(FMTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
            }
            .multilineTextAlignment(.center)

            Button {
                store.send(.startTapped)
            } label: {
                Label("시작", systemImage: "play.fill")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
            }
            .background(FMColors.primaryAction, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
            .accessibilityLabel("미소 측정 시작")
            .accessibilityHint("미소 강도 기록을 시작합니다")
        }
        .padding(FMSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
    }

    private var measuringCard: some View {
        VStack(spacing: FMSpacing.sm) {
            HStack(spacing: FMSpacing.sm) {
                Text(store.isSmiling ? "😄" : "🙂")
                    .font(.system(size: 32))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text(store.isSmiling ? "좋아요, 그 미소 그대로!" : "입꼬리를 살짝 올려보세요")
                        .font(FMTypography.title1)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    store.send(.stopTapped)
                } label: {
                    Label("종료", systemImage: "stop.fill")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(.white)
                        .padding(.horizontal, FMSpacing.sm)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                .accessibilityLabel("측정 종료")
                .accessibilityHint("측정을 마치고 미소 리포트를 표시합니다")
            }

            ProgressView(value: min(max(store.smileScore, 0), 1))
                .tint(store.isSmiling ? .green : .white.opacity(0.6))
                .accessibilityLabel("현재 미소 강도")
                .accessibilityValue("\(Int(store.smileScore * 100))퍼센트")
        }
        .padding(FMSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
    }

    // MARK: - Report

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            Text("미소 리포트")
                .font(FMTypography.title1)
                .foregroundStyle(.white)

            SmileReportChart(samples: store.samples)
                .frame(height: 150)
                .accessibilityLabel("시간에 따른 미소 강도 그래프")
                .accessibilityValue("미소 유지율 \(Int(store.smileRatio * 100))퍼센트, 평균 강도 \(Int(store.averageScore * 100))퍼센트")

            HStack(spacing: FMSpacing.md) {
                reportStat(title: "측정 시간", value: durationText)
                reportStat(title: "미소 유지율", value: "\(Int(store.smileRatio * 100))%")
                reportStat(title: "평균 미소 강도", value: "\(Int(store.averageScore * 100))%")
            }

            Text(reportMessage)
                .font(FMTypography.callout)
                .foregroundStyle(.white.opacity(0.7))

            HStack(alignment: .top, spacing: FMSpacing.xs) {
                Image(systemName: "info.circle")
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityHidden(true)

                Text("""
                미소 기준 \(thresholdPercentText)%는 입꼬리가 올라간 정도예요.
                옅은 미소는 약 \(thresholdPercentText)%, 활짝 웃으면 70% 이상이에요.
                기준선 위에 머문 시간의 비율이 미소 유지율이에요.
                """)
                    .font(FMTypography.caption1)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FMSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            HStack(spacing: FMSpacing.sm) {
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview("FlyMate 미소 리포트", image: shareImage)
                    ) {
                        Label("공유", systemImage: "square.and.arrow.up")
                            .font(FMTypography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                    }
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
                    .accessibilityLabel("미소 리포트 공유")
                    .accessibilityHint("리포트 이미지를 다른 앱으로 공유합니다")
                }

                Button {
                    store.send(.retryTapped)
                } label: {
                    Label("다시 연습", systemImage: "arrow.counterclockwise")
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                }
                .background(FMColors.primaryAction, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))
                .accessibilityLabel("다시 연습 시작")
                .accessibilityHint("리포트를 닫고 새 측정을 준비합니다")
            }
        }
        .padding(FMSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .task {
            shareImage = renderShareImage()
        }
    }

    private func reportStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            Text(title)
                .font(FMTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(FMTypography.title1)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var thresholdPercentText: String {
        "\(Int(AppConstants.PracticeMirror.smileThreshold * 100))"
    }

    private var durationText: String {
        Duration.seconds(store.measuredDuration).formatted(.time(pattern: .minuteSecond))
    }

    @MainActor
    private func renderShareImage() -> Image? {
        let renderer = ImageRenderer(content: SmileReportShareCard(
            samples: store.samples,
            smileRatio: store.smileRatio,
            averageScore: store.averageScore,
            durationText: durationText,
            date: store.startedAt ?? Date()
        ))
        renderer.scale = 2 // 540×675pt × 2 = 1080×1350px (인스타 피드 4:5)
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private var reportMessage: String {
        switch store.smileRatio {
        case 0.8...:
            return "훌륭해요! 면접 내내 안정적으로 미소를 유지했어요"
        case 0.5..<0.8:
            return "잘하고 있어요! 미소가 흐려진 구간만 보완하면 더 좋아질 거예요"
        default:
            return "그래프에서 미소가 끊긴 구간을 확인하고 다시 연습해보세요"
        }
    }

    private var timerBadge: some View {
        HStack(spacing: FMSpacing.xxs) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            // 벽시계가 아닌 샘플 누적 기반 — 얼굴이 인식되지 않는 동안은 멈춘다
            Text(Duration.seconds(store.measuredDuration).formatted(.time(pattern: .minuteSecond)))
                .font(FMTypography.largeTitle)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, FMSpacing.sm)
        .frame(minHeight: 44)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityLabel("측정 경과 시간")
    }

    // MARK: - Top Controls

    private var mirrorToggleButton: some View {
        Button {
            store.send(.mirrorToggleTapped)
        } label: {
            Label("좌우반전", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(FMTypography.feedMetaEmphasis)
                .foregroundStyle(.white)
                .padding(.horizontal, FMSpacing.sm)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("좌우반전")
        .accessibilityHint("화면의 좌우를 반전합니다")
    }

    private var closeButton: some View {
        Button {
            store.send(.closeTapped)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: FMSizing.IconSize.md, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("연습 거울 닫기")
        .accessibilityHint("미소 연습을 종료하고 이전 화면으로 돌아갑니다")
    }

    private var unsupportedView: some View {
        VStack(spacing: FMSpacing.sm) {
            Image(systemName: "face.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityHidden(true)

            Text("이 기기에서는 얼굴 추적을 지원하지 않아요")
                .font(FMTypography.title1)
                .foregroundStyle(.white)

            Text("미소 연습 거울은 실제 기기에서 사용할 수 있어요")
                .font(FMTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(FMSpacing.xl)
    }
}
