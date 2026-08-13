import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct LoginFeatureTests {
    private nonisolated static let appleSignInResult = AppleSignInResult(
        idToken: "mock-id-token",
        nonce: "mock-nonce",
        fullName: nil,
        email: nil,
        authorizationCode: "mock-auth-code"
    )

    @Test
    func Apple_로그인_성공() async {
        let mockUser = User.mock

        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.appleSignInClient.signIn = { Self.appleSignInResult }
            $0.authClient.signInWithApple = { _, _ in mockUser }
        }

        await store.send(.appleLoginTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.appleSignInResult.success)

        await store.receive(\.loginResponse.success) {
            $0.isLoading = false
        }
    }

    @Test
    func Apple_로그인_실패() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.appleSignInClient.signIn = { Self.appleSignInResult }
            $0.authClient.signInWithApple = { _, _ in
                throw AppError.network(.noConnection)
            }
        }

        await store.send(.appleLoginTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.appleSignInResult.success)

        await store.receive(\.loginResponse.failure) {
            $0.isLoading = false
            $0.error = .network(.noConnection)
        }
    }

    @Test
    func 로고_5회_탭하면_이메일_로그인_시트가_열린다() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        for count in 1..<LoginFeature.hiddenLoginTapThreshold {
            await store.send(.logoTapped) {
                $0.logoTapCount = count
            }
        }

        await store.send(.logoTapped) {
            $0.logoTapCount = 0
            $0.showsEmailLogin = true
        }
    }

    @Test
    func 이메일_로그인_성공시_시트가_닫히고_입력이_초기화된다() async {
        let mockUser = User.mock

        var state = LoginFeature.State()
        state.showsEmailLogin = true

        let store = TestStore(initialState: state) {
            LoginFeature()
        } withDependencies: {
            $0.authClient.signInWithEmail = { _, _ in mockUser }
        }

        await store.send(.emailChanged("reviewer@flymate.app")) {
            $0.email = "reviewer@flymate.app"
        }
        await store.send(.passwordChanged("password")) {
            $0.password = "password"
        }

        await store.send(.emailLoginTapped) {
            $0.isLoading = true
            $0.error = nil
        }

        await store.receive(\.loginResponse.success) {
            $0.isLoading = false
            $0.showsEmailLogin = false
            $0.email = ""
            $0.password = ""
        }
    }

    @Test
    func 이메일_또는_비밀번호가_비어있으면_로그인하지_않는다() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        }

        await store.send(.emailLoginTapped)
    }

    @Test
    func 에러_다이얼로그_닫기() async {
        var state = LoginFeature.State()
        state.error = .network(.noConnection)

        let store = TestStore(initialState: state) {
            LoginFeature()
        }

        await store.send(.errorDismissed) {
            $0.error = nil
        }
    }
}

// MARK: - Mock Data

extension User {
    static let mock = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        email: "test@example.com",
        name: "테스트 유저",
        provider: .apple,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
