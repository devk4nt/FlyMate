import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct LoginFeature {
    /// 이메일 로그인 시트를 여는 히든 제스처의 로고 탭 횟수 (App Store 심사용)
    public static let hiddenLoginTapThreshold = 5

    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var error: AppError?
        public var logoTapCount = 0
        public var showsEmailLogin = false
        public var email = ""
        public var password = ""

        public init() {}
    }

    public enum Action: Equatable {
        case appleLoginTapped
        case appleSignInResult(Result<AppleSignInResult, AppleSignInError>)
        case kakaoLoginTapped
        case kakaoSignInResult(Result<String, KakaoSignInError>)
        case logoTapped
        case emailChanged(String)
        case passwordChanged(String)
        case emailLoginTapped
        case emailLoginDismissed
        case loginResponse(Result<User, AppError>)
        case errorDismissed
    }

    @Dependency(\.authClient) private var authClient
    @Dependency(\.appleSignInClient) private var appleSignInClient
    @Dependency(\.kakaoSignInClient) private var kakaoSignInClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appleLoginTapped:
                state.isLoading = true
                state.error = nil
                let client = appleSignInClient
                return .run { send in
                    do {
                        let result = try await client.signIn()
                        await send(.appleSignInResult(.success(result)))
                    } catch let error as AppleSignInError {
                        await send(.appleSignInResult(.failure(error)))
                    } catch {
                        await send(.appleSignInResult(.failure(.failed(error.localizedDescription))))
                    }
                }

            case .appleSignInResult(.success(let result)):
                let client = authClient
                return .run { send in
                    do {
                        let user = try await client.signInWithApple(result.idToken, result.nonce)
                        await send(.loginResponse(.success(user)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.loginResponse(.failure(appError)))
                    }
                }

            case .appleSignInResult(.failure(let error)):
                state.isLoading = false
                if error == .canceled { return .none }
                state.error = .unexpected(error.localizedDescription ?? "Apple 로그인에 실패했습니다.")
                return .none

            case .kakaoLoginTapped:
                state.isLoading = true
                state.error = nil
                let client = kakaoSignInClient
                return .run { send in
                    do {
                        let accessToken = try await client.signIn()
                        await send(.kakaoSignInResult(.success(accessToken)))
                    } catch let error as KakaoSignInError {
                        await send(.kakaoSignInResult(.failure(error)))
                    } catch {
                        await send(.kakaoSignInResult(.failure(.failed(error.localizedDescription))))
                    }
                }

            case .kakaoSignInResult(.success(let accessToken)):
                let client = authClient
                return .run { send in
                    do {
                        let user = try await client.signInWithKakao(accessToken)
                        await send(.loginResponse(.success(user)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.loginResponse(.failure(appError)))
                    }
                }

            case .kakaoSignInResult(.failure(let error)):
                state.isLoading = false
                if error == .canceled { return .none }
                state.error = .unexpected(error.localizedDescription ?? "카카오 로그인에 실패했습니다.")
                return .none

            case .logoTapped:
                state.logoTapCount += 1
                guard state.logoTapCount >= Self.hiddenLoginTapThreshold else { return .none }
                state.logoTapCount = 0
                state.showsEmailLogin = true
                return .none

            case .emailChanged(let email):
                state.email = email
                return .none

            case .passwordChanged(let password):
                state.password = password
                return .none

            case .emailLoginTapped:
                // QuickType 공백/붙여넣기 개행이 딸려 와 인증 실패하는 것을 방지
                let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                let password = state.password.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !email.isEmpty, !password.isEmpty else { return .none }
                state.isLoading = true
                state.error = nil
                let client = authClient
                return .run { send in
                    do {
                        let user = try await client.signInWithEmail(email, password)
                        await send(.loginResponse(.success(user)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.loginResponse(.failure(appError)))
                    }
                }

            case .emailLoginDismissed:
                state.showsEmailLogin = false
                state.email = ""
                state.password = ""
                return .none

            case .loginResponse(.success):
                state.isLoading = false
                state.showsEmailLogin = false
                state.email = ""
                state.password = ""
                return .none

            case .loginResponse(.failure(let error)):
                state.isLoading = false
                state.error = error
                return .none

            case .errorDismissed:
                state.error = nil
                return .none
            }
        }
    }
}
