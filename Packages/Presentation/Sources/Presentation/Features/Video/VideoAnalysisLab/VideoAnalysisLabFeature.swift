import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct VideoAnalysisLabFeature {
    @ObservableState
    public struct State: Equatable {
        /// 영상에서 추출한 AI 분석 재료 (음성 + 캡처 프레임)
        public var media: LoadingState<InterviewInsightRequest> = .idle
        public var insight: LoadingState<InterviewInsight> = .idle

        public init() {}
    }

    public enum Action: Equatable {
        case videoSelected(URL)
        case mediaResponse(Result<InterviewInsightRequest, AppError>)
        case insightTapped
        case insightResponse(Result<InterviewInsight, AppError>)
        case resetTapped
    }

    private enum CancelID { case media, insight }

    @Dependency(\.audioExtractionClient) private var audioClient
    @Dependency(\.videoFrameExtractionClient) private var frameClient
    @Dependency(\.interviewInsightClient) private var insightClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .videoSelected(let url):
                state.media = .loading
                state.insight = .idle
                let audio = audioClient
                let frameExtractor = frameClient
                return .run { send in
                    defer { try? FileManager.default.removeItem(at: url) }
                    do {
                        // 음성 추출과 프레임 캡처를 병렬 실행 — 프레임 실패는 빈 배열로 흡수
                        async let frames = frameExtractor.extractFrames(url)
                        let extracted = try await audio.extractAudio(url)
                        let request = InterviewInsightRequest(
                            duration: extracted.duration,
                            audioBase64: extracted.m4aBase64,
                            frames: await frames
                        )
                        guard request.audioBase64 != nil || !request.frames.isEmpty else {
                            throw AppError.unexpected("영상에서 음성과 화면을 추출하지 못했어요.")
                        }
                        await send(.mediaResponse(.success(request)))
                    } catch is CancellationError {
                        // 화면 이탈 또는 새 영상 선택으로 취소됨 — 상태 갱신 불필요
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.mediaResponse(.failure(appError)))
                    }
                }
                .cancellable(id: CancelID.media, cancelInFlight: true)

            case .mediaResponse(.success(let request)):
                state.media = .loaded(request)
                return .none

            case .mediaResponse(.failure(let error)):
                state.media = .failed(error)
                return .none

            case .insightTapped:
                guard case .loaded(let request) = state.media else { return .none }
                if case .loading = state.insight { return .none }
                state.insight = .loading
                let client = insightClient
                return .run { send in
                    do {
                        let insight = try await client.generateInsight(request)
                        await send(.insightResponse(.success(insight)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.insightResponse(.failure(appError)))
                    }
                }
                .cancellable(id: CancelID.insight, cancelInFlight: true)

            case .insightResponse(.success(let insight)):
                state.insight = .loaded(insight)
                return .none

            case .insightResponse(.failure(let error)):
                state.insight = .failed(error)
                return .none

            case .resetTapped:
                state.media = .idle
                state.insight = .idle
                return .merge(
                    .cancel(id: CancelID.media),
                    .cancel(id: CancelID.insight)
                )
            }
        }
    }
}
