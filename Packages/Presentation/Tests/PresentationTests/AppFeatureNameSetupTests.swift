import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

/// Apple 로그인은 이름을 주지 않아 서버가 `User28` 같은 임시 이름을 넣는다.
/// 서로 피드백을 주고받는 앱이라 임시 이름이면 상대가 사람으로 보이지 않는다.
@MainActor
struct AppFeatureNameSetupTests {
    private static func user(name: String) -> User {
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            email: "test@example.com",
            name: name,
            provider: .apple,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test
    func 서버_기본이름만_임시이름으로_판정한다() {
        #expect(AppFeature.hasPlaceholderName("User"))
        #expect(AppFeature.hasPlaceholderName("User28"))
        // 사용자가 직접 정한 이름은 건드리지 않는다
        #expect(!AppFeature.hasPlaceholderName("Userna"))
        #expect(!AppFeature.hasPlaceholderName("user28"))
        #expect(!AppFeature.hasPlaceholderName("승무원준비생"))
    }

    @Test
    func 임시이름이면_이름설정_시트를_띄우고_다시_묻지_않게_표시한다() async {
        let prompted = LockIsolated<[Bool]>([])
        var state = AppFeature.State()
        state.currentUser = Self.user(name: "User28")

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient.boolForKey = { _ in false }
            $0.userDefaultsClient.setBool = { value, key in
                if key == AppFeature.nameSetupPromptedKey { prompted.withValue { $0.append(value) } }
            }
        }
        store.exhaustivity = .off

        await store.send(.checkNameSetup)

        #expect(store.state.nameSetup?.isNameSetup == true)
        // 임시 이름을 지우고 쓰는 수고가 없도록 입력란은 비워 둔다
        #expect(store.state.nameSetup?.name == "")
        #expect(prompted.value == [true])
    }

    @Test
    func 이미_한번_물어봤으면_다시_띄우지_않는다() async {
        var state = AppFeature.State()
        state.currentUser = Self.user(name: "User28")

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient.boolForKey = { $0 == AppFeature.nameSetupPromptedKey }
        }

        await store.send(.checkNameSetup)
        #expect(store.state.nameSetup == nil)
    }

    @Test
    func 직접_정한_이름이면_띄우지_않는다() async {
        var state = AppFeature.State()
        state.currentUser = Self.user(name: "김하늘")

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.userDefaultsClient.boolForKey = { _ in false }
        }

        await store.send(.checkNameSetup)
        #expect(store.state.nameSetup == nil)
    }
}
