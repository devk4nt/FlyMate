import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct VideoAnalysisLabView: View {
    @Bindable var store: StoreOf<VideoAnalysisLabFeature>
    @State private var isVideoPickerPresented = false

    public init(store: StoreOf<VideoAnalysisLabFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FMSpacing.lg) {
                introductionCard
                analysisContent
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.lg)
        }
        .background(FMColors.canvas)
        .navigationTitle("AI 면접 분석 실험실")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isVideoPickerPresented) {
            VideoPickerView(
                maximumDuration: AppConstants.maxVideoDurationSeconds,
                onPick: { url in
                    isVideoPickerPresented = false
                    store.send(.videoSelected(url))
                },
                onCancel: {
                    isVideoPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Content

    private var introductionCard: some View {
        FMCard(style: .hero, background: FMColors.supportSurface) {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(FMColors.brandInk)
                    .accessibilityHidden(true)

                Text("면접 답변을 AI가 문장별로 분석해요")
                    .font(FMTypography.title1)
                    .foregroundStyle(FMColors.brandTitle)

                Text("영상 속 답변 음성과 5초 간격 캡처 화면을 AI로 보내 모든 문장을 텍스트로 바꾸고, 문장마다 괜찮았던 점과 아쉬운 점을 짚어드려요. 영상 원본은 기기 밖으로 나가지 않아요.")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                FMButton(
                    title: buttonTitle,
                    style: .primary,
                    isLoading: store.media.isLoading
                ) {
                    isVideoPickerPresented = true
                }
                .accessibilityHint("최대 3분 길이의 분석할 영상을 선택합니다")
            }
        }
    }

    @ViewBuilder
    private var analysisContent: some View {
        switch store.media {
        case .idle:
            guidanceCard

        case .loading:
            FMCard {
                VStack(spacing: FMSpacing.md) {
                    ProgressView()
                        .controlSize(.large)
                    Text("영상에서 음성과 화면을 추출하고 있어요")
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.label)
                    Text("영상 길이와 기기 성능에 따라 잠시 걸릴 수 있어요.")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("영상 준비 중")
            }

        case .loaded:
            VStack(alignment: .leading, spacing: FMSpacing.lg) {
                insightSection

                FMButton(title: "다른 영상 분석하기", style: .secondary) {
                    isVideoPickerPresented = true
                }
                .accessibilityHint("새 영상을 선택해 현재 결과를 교체합니다")
            }

        case .failed(let error):
            FMErrorView(error: error) {
                store.send(.resetTapped)
            }
        }
    }

    private var guidanceCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Label("실험 기능 안내", systemImage: "flask.fill")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text("AI가 승무원 면접 관점에서 표현과 전달 방식을 짚어주는 연습 도구입니다. 자동 전사 특성상 오탈자가 있을 수 있으며, 감정이나 합격 가능성은 평가하지 않습니다.")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - AI Insight

    @ViewBuilder
    private var insightSection: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Label("AI 문장별 분석", systemImage: "sparkles")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                switch store.insight {
                case .idle:
                    Text("답변 음성과 캡처 화면을 AI에 보내 모든 문장을 텍스트로 변환하고, 문장마다 승무원 면접 관점의 피드백을 받아요.")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                    FMButton(title: "AI 분석 받기", style: .secondary) {
                        store.send(.insightTapped)
                    }
                    .accessibilityHint("답변 음성과 캡처 화면을 기반으로 문장별 AI 피드백을 생성합니다")

                case .loading:
                    HStack(spacing: FMSpacing.sm) {
                        ProgressView()
                        Text("AI가 답변을 텍스트로 바꾸고 문장별 피드백을 작성하고 있어요. 최대 1분 정도 걸릴 수 있어요.")
                            .font(FMTypography.callout)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("AI 분석 생성 중")

                case .loaded(let insight):
                    insightResult(insight)

                case .failed(let error):
                    FMErrorView(error: error) {
                        store.send(.insightTapped)
                    }
                }
            }
        }
    }

    private func insightResult(_ insight: InterviewInsight) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            Text(insight.summary)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if !insight.sentences.isEmpty {
                Divider()

                Text("문장별 피드백")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                ForEach(Array(insight.sentences.enumerated()), id: \.offset) { index, sentence in
                    if index > 0 {
                        Divider()
                    }
                    sentenceRow(sentence)
                }
            }
        }
    }

    private func sentenceRow(_ sentence: InterviewInsight.Sentence) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Text(formattedTime(sentence.start))
                .font(FMTypography.feedMetaEmphasis)
                .foregroundStyle(FMColors.brandInk)
                .monospacedDigit()

            Text(sentence.text)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)

            if let strength = sentence.strength {
                feedbackItem(
                    title: "좋았던 점",
                    text: strength,
                    systemImage: "checkmark.circle.fill",
                    tint: FMColors.success
                )
            }
            if let weakness = sentence.weakness {
                feedbackItem(
                    title: "아쉬운 점",
                    text: weakness,
                    systemImage: "exclamationmark.circle.fill",
                    tint: FMColors.warning
                )
            }
            if let suggestion = sentence.suggestion {
                feedbackItem(
                    title: "이렇게 해보세요",
                    text: suggestion,
                    systemImage: "lightbulb.fill",
                    tint: FMColors.brandInk
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
    }

    private func feedbackItem(
        title: String,
        text: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xxs) {
            HStack(spacing: FMSpacing.xxs) {
                Image(systemName: systemImage)
                    .font(FMTypography.authorName)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(FMTypography.authorName)
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(text)")
    }

    // MARK: - Formatting Helpers

    private var buttonTitle: String {
        store.media.value == nil ? "영상 선택하기" : "새 영상 선택하기"
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(0, Int(time.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - Preview Mock

private let previewRequest = InterviewInsightRequest(
    duration: 45,
    audioBase64: "bTRh",
    frames: []
)

private let previewInsight = InterviewInsight(
    summary: "자기소개와 지원 동기가 간결하게 전달되고, 경험을 근거로 든 점이 좋습니다. 가장 우선 개선할 점은 문장 사이 호흡이 급해 암기한 듯 들리는 부분으로, 핵심어 앞에서 잠깐 속도를 늦추는 연습을 해 보세요. 발음과 억양은 데이터만으로 판단하기 어려웠습니다.",
    sentences: [
        InterviewInsight.Sentence(
            start: 2,
            text: "안녕하십니까, 지원자 홍길동입니다.",
            strength: "첫인사의 속도와 끝맺음이 안정적이에요.",
            weakness: nil,
            suggestion: nil
        ),
        InterviewInsight.Sentence(
            start: 8,
            text: "저는 고객의 불편을 먼저 알아차리는 승무원이 되고 싶습니다.",
            strength: "결론을 먼저 말해 지원 동기가 분명하게 전달돼요.",
            weakness: "답변 시작 전 호흡이 길어 흐름이 끊겨 보여요.",
            suggestion: "이 문장은 첫인사와 바로 이어 붙여 한 호흡으로 말해 보세요."
        ),
        InterviewInsight.Sentence(
            start: 16,
            text: "카페 아르바이트를 하며 단골손님의 주문을 기억해 먼저 준비해 드린 경험이 있습니다.",
            strength: nil,
            weakness: "경험의 결과가 빠져 있어 설득력이 아쉬워요.",
            suggestion: "행동 뒤에 결과 한 문장(예: 손님이 이름을 기억해 주셨습니다)을 덧붙여 보세요."
        ),
        InterviewInsight.Sentence(
            start: 27,
            text: "감사합니다.",
            strength: "짧고 명확한 끝맺음으로 깔끔하게 마무리했어요.",
            weakness: nil,
            suggestion: nil
        ),
    ]
)

// MARK: - Previews

#Preview("문장별 분석 결과") {
    var state = VideoAnalysisLabFeature.State()
    state.media = .loaded(previewRequest)
    state.insight = .loaded(previewInsight)
    return NavigationStack {
        VideoAnalysisLabView(
            store: Store(initialState: state) { VideoAnalysisLabFeature() }
        )
    }
}

#Preview("분석 대기 (버튼 노출)") {
    var state = VideoAnalysisLabFeature.State()
    state.media = .loaded(previewRequest)
    return NavigationStack {
        VideoAnalysisLabView(
            store: Store(initialState: state) { VideoAnalysisLabFeature() }
        )
    }
}

#Preview("분석 생성 중") {
    var state = VideoAnalysisLabFeature.State()
    state.media = .loaded(previewRequest)
    state.insight = .loading
    return NavigationStack {
        VideoAnalysisLabView(
            store: Store(initialState: state) { VideoAnalysisLabFeature() }
        )
    }
}

#Preview("초기 화면") {
    NavigationStack {
        VideoAnalysisLabView(
            store: Store(initialState: VideoAnalysisLabFeature.State()) {
                VideoAnalysisLabFeature()
            }
        )
    }
}

#Preview("분석 실패") {
    var state = VideoAnalysisLabFeature.State()
    state.media = .loaded(previewRequest)
    state.insight = .failed(.unexpected("분석 생성에 실패했어요. 잠시 후 다시 시도해 주세요."))
    return NavigationStack {
        VideoAnalysisLabView(
            store: Store(initialState: state) { VideoAnalysisLabFeature() }
        )
    }
}
