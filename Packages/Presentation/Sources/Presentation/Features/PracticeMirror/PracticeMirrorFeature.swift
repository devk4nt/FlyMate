import Foundation
import ComposableArchitecture
import Core

@Reducer
public struct PracticeMirrorFeature {
    @ObservableState
    public struct State: Equatable {
        public enum Phase: Equatable, Sendable {
            /// 시작 전 — 카메라 프리뷰만 표시
            case ready
            /// 측정 중 — 샘플 누적
            case measuring
            /// 종료 — 미소 리포트 표시
            case finished
        }

        public var phase: Phase = .ready
        /// 현재 미소 강도 (0...1, mouthSmileLeft/Right 평균)
        public var smileScore: Double = 0
        /// 측정 중 누적된 미소 강도 샘플 (sampleInterval 간격)
        public var samples: [Double] = []
        /// 측정 시작 시점 — 경과 시간 표시 기준
        public var startedAt: Date?
        /// 거울 모드 — 기본은 비반전(면접관이 보는 시점), 켜면 거울처럼 좌우 반전
        public var isMirrored = false
        /// 최소 측정 시간을 못 채우고 종료해 리포트 없이 돌아왔는지
        public var isShortSessionNoticeVisible = false
        /// 앱 평가 요청 시점 신호 — 뷰가 관찰해 requestReview를 호출한다
        public var isReviewPromptRequested = false

        public var isSmiling: Bool {
            smileScore >= AppConstants.PracticeMirror.smileThreshold
        }

        /// 측정 시간 중 미소를 유지한 비율 (0...1)
        public var smileRatio: Double {
            guard !samples.isEmpty else { return 0 }
            let smiling = samples.filter { $0 >= AppConstants.PracticeMirror.smileThreshold }.count
            return Double(smiling) / Double(samples.count)
        }

        /// 평균 미소 강도 (0...1)
        public var averageScore: Double {
            guard !samples.isEmpty else { return 0 }
            return samples.reduce(0, +) / Double(samples.count)
        }

        /// 측정 시간 (초)
        public var measuredDuration: TimeInterval {
            Double(samples.count) * AppConstants.PracticeMirror.sampleInterval
        }

        public init() {}
    }

    public enum Action: Equatable {
        case smileSampled(Double)
        case startTapped
        case stopTapped
        case retryTapped
        case mirrorToggleTapped
        case closeTapped
        case reviewPromptTriggered
    }



    @Dependency(\.dismiss) private var dismiss
    @Dependency(\.date.now) private var now
    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.smileReminderClient) private var smileReminderClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .smileSampled(let score):
                // 리포트 표시 중에는 상태를 갱신하지 않는다 (불필요한 재렌더 방지)
                guard state.phase != .finished else { return .none }
                state.smileScore = score
                if state.phase == .measuring {
                    state.samples.append(score)
                }
                return .none

            case .startTapped:
                state.phase = .measuring
                state.samples = []
                state.startedAt = now
                state.isShortSessionNoticeVisible = false
                return .none

            case .stopTapped:
                guard state.phase == .measuring else { return .none }
                guard state.measuredDuration >= AppConstants.PracticeMirror.minimumReportDuration else {
                    state.phase = .ready
                    state.samples = []
                    state.startedAt = nil
                    state.isShortSessionNoticeVisible = true
                    return .none
                }
                state.phase = .finished
                let defaults = userDefaultsClient
                let reminder = smileReminderClient
                let clock = clock
                let completedCount = defaults.integerForKey(AppConstants.PracticeMirror.UserDefaultsKey.completedReportCount) + 1
                let smileRatio = state.smileRatio
                return .run { send in
                    await defaults.setInteger(completedCount, AppConstants.PracticeMirror.UserDefaultsKey.completedReportCount)

                    // 최근 유지율 저장(기기 한정) — 1일 1미소 알림 개인화 문구에 사용
                    let ratioPercent = Int(smileRatio * 100)
                    await defaults.setInteger(ratioPercent + 1, AppConstants.PracticeMirror.UserDefaultsKey.recentSmileRatioPercentPlusOne)
                    if defaults.boolForKey(AppConstants.PracticeMirror.UserDefaultsKey.reminderEnabled) {
                        let storedMinutes = defaults.integerForKey(AppConstants.PracticeMirror.UserDefaultsKey.reminderMinutesPlusOne)
                        let minutes = storedMinutes > 0 ? storedMinutes - 1 : AppConstants.PracticeMirror.reminderDefaultMinutes
                        await reminder.reschedule(minutes, ratioPercent)
                    }

                    guard completedCount >= AppConstants.PracticeMirror.reviewMinCompletedReports,
                          smileRatio >= AppConstants.PracticeMirror.reviewMinSmileRatio else { return }
                    try await clock.sleep(for: .seconds(AppConstants.PracticeMirror.reviewPromptDelay))
                    await send(.reviewPromptTriggered)
                }

            case .reviewPromptTriggered:
                state.isReviewPromptRequested = true
                return .none

            case .retryTapped:
                state.phase = .ready
                state.samples = []
                state.startedAt = nil
                return .none

            case .mirrorToggleTapped:
                state.isMirrored.toggle()
                return .none

            case .closeTapped:
                let dismiss = dismiss
                return .run { _ in await dismiss() }
            }
        }
    }
}
