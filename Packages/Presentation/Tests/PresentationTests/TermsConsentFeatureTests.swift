import Foundation
import Testing
import ComposableArchitecture
import Core
@testable import Presentation

@MainActor
struct TermsConsentFeatureTests {

    @Test
    func 동의시_플래그_저장_및_delegate_전달() async {
        let savedKey = LockIsolated<String?>(nil)
        let savedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: TermsConsentFeature.State()) {
            TermsConsentFeature()
        } withDependencies: {
            $0.userDefaultsClient.setBool = { value, key in
                savedValue.setValue(value)
                savedKey.setValue(key)
            }
        }

        await store.send(.agreeTapped)
        await store.receive(\.delegate)

        #expect(savedKey.value == TermsConsentFeature.consentKey)
        #expect(savedValue.value == true)
    }
}
