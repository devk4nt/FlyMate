import Foundation
import Testing
import ComposableArchitecture
import Core
@testable import Presentation

@MainActor
struct PracticeMirrorFeatureTests {
    @Test
    func 시작_전에는_샘플이_누적되지_않는다() async {
        let store = TestStore(initialState: PracticeMirrorFeature.State()) {
            PracticeMirrorFeature()
        }

        await store.send(.smileSampled(0.5)) {
            $0.smileScore = 0.5
        }

        #expect(store.state.samples.isEmpty)
    }

    @Test
    func 측정_흐름_시작_샘플_종료_리포트() async {
        let now = Date(timeIntervalSince1970: 1_000)
        let store = TestStore(initialState: PracticeMirrorFeature.State()) {
            PracticeMirrorFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = ImmediateClock()
            $0.userDefaultsClient.integerForKey = { _ in 0 }
            $0.userDefaultsClient.setInteger = { _, _ in }
        }

        await store.send(.startTapped) {
            $0.phase = .measuring
            $0.startedAt = now
        }

        await store.send(.smileSampled(0.5)) {
            $0.smileScore = 0.5
            $0.samples = [0.5]
        }

        await store.send(.smileSampled(0.1)) {
            $0.smileScore = 0.1
            $0.samples = [0.5, 0.1]
        }

        // 최소 측정 시간을 채우기 위해 샘플 보충 (10초 = 100샘플)
        let filler = [Double](repeating: 0.5, count: 98)
        for score in filler {
            await store.send(.smileSampled(score)) {
                $0.smileScore = score
                $0.samples.append(score)
            }
        }

        await store.send(.stopTapped) {
            $0.phase = .finished
        }

        #expect(abs(store.state.smileRatio - 99.0 / 100.0) < 0.0001)
        #expect(abs(store.state.measuredDuration - 10) < 0.0001)

        // 종료 후 들어오는 샘플은 무시된다
        await store.send(.smileSampled(0.9))
        #expect(store.state.smileScore == 0.5)
        #expect(store.state.samples.count == 100)
    }

    @Test
    func 세_번째_리포트가_유지율_높으면_평가를_요청한다() async {
        var initialState = PracticeMirrorFeature.State()
        initialState.phase = .measuring
        initialState.samples = [Double](repeating: 0.8, count: 100) // 10초, 유지율 100%
        initialState.startedAt = Date(timeIntervalSince1970: 1_000)

        let savedCount = LockIsolated(0)
        let store = TestStore(initialState: initialState) {
            PracticeMirrorFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.userDefaultsClient.integerForKey = { _ in 2 } // 이번이 3회째
            $0.userDefaultsClient.setInteger = { value, _ in savedCount.setValue(value) }
        }

        await store.send(.stopTapped) {
            $0.phase = .finished
        }

        await store.receive(\.reviewPromptTriggered) {
            $0.isReviewPromptRequested = true
        }

        #expect(savedCount.value == 3)
    }

    @Test
    func 최소_시간_미만_종료는_리포트_없이_준비로_돌아간다() async {
        let now = Date(timeIntervalSince1970: 1_000)
        var initialState = PracticeMirrorFeature.State()
        initialState.phase = .measuring
        initialState.samples = [Double](repeating: 0.5, count: 50) // 5초
        initialState.startedAt = now

        let store = TestStore(initialState: initialState) {
            PracticeMirrorFeature()
        } withDependencies: {
            $0.date = .constant(now)
        }

        await store.send(.stopTapped) {
            $0.phase = .ready
            $0.samples = []
            $0.startedAt = nil
            $0.isShortSessionNoticeVisible = true
        }

        // 다시 시작하면 안내가 사라진다
        await store.send(.startTapped) {
            $0.phase = .measuring
            $0.startedAt = now
            $0.isShortSessionNoticeVisible = false
        }
    }

    @Test
    func 다시_연습하면_준비_상태로_초기화된다() async {
        let now = Date(timeIntervalSince1970: 1_000)
        var initialState = PracticeMirrorFeature.State()
        initialState.phase = .finished
        initialState.samples = [0.5, 0.7]
        initialState.startedAt = now

        let store = TestStore(initialState: initialState) {
            PracticeMirrorFeature()
        }

        await store.send(.retryTapped) {
            $0.phase = .ready
            $0.samples = []
            $0.startedAt = nil
        }
    }

    @Test
    func 좌우반전_토글() async {
        let store = TestStore(initialState: PracticeMirrorFeature.State()) {
            PracticeMirrorFeature()
        }

        await store.send(.mirrorToggleTapped) {
            $0.isMirrored = true
        }
        await store.send(.mirrorToggleTapped) {
            $0.isMirrored = false
        }
    }
}
