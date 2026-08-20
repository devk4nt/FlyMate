import Foundation
import Testing
import ComposableArchitecture
import Core
@testable import Presentation

@MainActor
struct OnboardingFeatureTests {

    @Test
    func 첫영상올리기_탭시_완료_저장_및_firstUploadRequested_delegate_전달() async {
        let savedKey = LockIsolated<String?>(nil)
        let savedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.userDefaultsClient.setBool = { value, key in
                savedValue.setValue(value)
                savedKey.setValue(key)
            }
        }

        await store.send(.uploadFirstVideoTapped)
        await store.receive(\.delegate.firstUploadRequested)

        #expect(savedKey.value == "hasCompletedOnboarding")
        #expect(savedValue.value == true)
    }

    @Test
    func 나중에하기_탭시_완료_저장_및_onboardingCompleted_delegate_전달() async {
        let store = TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.userDefaultsClient.setBool = { _, _ in }
        }

        await store.send(.startTapped)
        await store.receive(\.delegate.onboardingCompleted)
    }
}
