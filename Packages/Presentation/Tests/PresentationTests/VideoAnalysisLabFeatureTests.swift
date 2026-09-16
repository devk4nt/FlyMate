import Foundation
import Testing
import ComposableArchitecture
import Core
import Domain
@testable import Presentation

@MainActor
struct VideoAnalysisLabFeatureTests {
    private nonisolated static let frames = [InterviewInsightRequest.Frame(time: 0, jpegBase64: "dGVzdA==")]
    private nonisolated static let request = InterviewInsightRequest(
        duration: 60,
        audioBase64: "bTRh",
        frames: frames
    )
    private nonisolated static let insight = InterviewInsight(
        summary: "안정적인 전달이에요.",
        sentences: [
            InterviewInsight.Sentence(
                start: 2,
                text: "안녕하십니까 지원자 홍길동입니다",
                strength: "첫인사가 밝고 끝맺음이 명확해요.",
                weakness: nil,
                suggestion: nil
            ),
        ]
    )

    @Test
    func 영상_선택_후_음성과_프레임을_추출한다() async {
        let videoURL = URL(fileURLWithPath: "/tmp/flymate-lab-test.mov")
        let store = TestStore(initialState: VideoAnalysisLabFeature.State()) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.audioExtractionClient.extractAudio = { _ in
                ExtractedAudio(duration: 60, m4aBase64: "bTRh")
            }
            $0.videoFrameExtractionClient.extractFrames = { _ in Self.frames }
        }

        await store.send(.videoSelected(videoURL)) {
            $0.media = .loading
        }
        await store.receive(\.mediaResponse.success) {
            $0.media = .loaded(Self.request)
        }
    }

    @Test
    func 미디어_추출_실패_시_오류_상태를_표시한다() async {
        let error = AppError.unexpected("영상 정보를 읽을 수 없어요.")
        let videoURL = URL(fileURLWithPath: "/tmp/flymate-lab-failure.mov")
        let store = TestStore(initialState: VideoAnalysisLabFeature.State()) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.audioExtractionClient.extractAudio = { _ in throw error }
            $0.videoFrameExtractionClient.extractFrames = { _ in [] }
        }

        await store.send(.videoSelected(videoURL)) {
            $0.media = .loading
        }
        await store.receive(\.mediaResponse.failure) {
            $0.media = .failed(error)
        }
    }

    @Test
    func 음성과_프레임_모두_없으면_오류_상태를_표시한다() async {
        let videoURL = URL(fileURLWithPath: "/tmp/flymate-lab-empty.mov")
        let store = TestStore(initialState: VideoAnalysisLabFeature.State()) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.audioExtractionClient.extractAudio = { _ in
                ExtractedAudio(duration: 60, m4aBase64: nil)
            }
            $0.videoFrameExtractionClient.extractFrames = { _ in [] }
        }

        await store.send(.videoSelected(videoURL)) {
            $0.media = .loading
        }
        await store.receive(\.mediaResponse.failure) {
            $0.media = .failed(.unexpected("영상에서 음성과 화면을 추출하지 못했어요."))
        }
    }

    @Test
    func AI_분석_성공_시_문장별_피드백을_표시한다() async {
        var initialState = VideoAnalysisLabFeature.State()
        initialState.media = .loaded(Self.request)

        let store = TestStore(initialState: initialState) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.interviewInsightClient.generateInsight = { request in
                #expect(request == Self.request)
                return Self.insight
            }
        }

        await store.send(.insightTapped) {
            $0.insight = .loading
        }
        await store.receive(\.insightResponse.success) {
            $0.insight = .loaded(Self.insight)
        }
    }

    @Test
    func AI_분석_실패_시_오류_상태를_표시한다() async {
        let error = AppError.unexpected("분석 생성 실패")
        var initialState = VideoAnalysisLabFeature.State()
        initialState.media = .loaded(Self.request)

        let store = TestStore(initialState: initialState) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.interviewInsightClient.generateInsight = { _ in throw error }
        }

        await store.send(.insightTapped) {
            $0.insight = .loading
        }
        await store.receive(\.insightResponse.failure) {
            $0.insight = .failed(error)
        }
    }

    @Test
    func 미디어_없이_분석_요청_시_무시한다() async {
        let store = TestStore(initialState: VideoAnalysisLabFeature.State()) {
            VideoAnalysisLabFeature()
        }

        await store.send(.insightTapped)
    }

    @Test
    func 새_영상_선택_시_기존_결과를_초기화한다() async {
        var initialState = VideoAnalysisLabFeature.State()
        initialState.media = .loaded(
            InterviewInsightRequest(duration: 30, audioBase64: "b2xk", frames: [])
        )
        initialState.insight = .loaded(Self.insight)

        let videoURL = URL(fileURLWithPath: "/tmp/flymate-lab-reset.mov")
        let store = TestStore(initialState: initialState) {
            VideoAnalysisLabFeature()
        } withDependencies: {
            $0.audioExtractionClient.extractAudio = { _ in
                ExtractedAudio(duration: 60, m4aBase64: "bTRh")
            }
            $0.videoFrameExtractionClient.extractFrames = { _ in Self.frames }
        }

        await store.send(.videoSelected(videoURL)) {
            $0.media = .loading
            $0.insight = .idle
        }
        await store.receive(\.mediaResponse.success) {
            $0.media = .loaded(Self.request)
        }
    }
}
