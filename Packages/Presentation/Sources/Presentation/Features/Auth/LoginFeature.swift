import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct LoginFeature {
    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var error: AppError?

        public init() {}
    }

    public enum Action: Equatable {
        case appleLoginTapped
        case appleSignInResult(Result<AppleSignInResult, AppleSignInError>)
        case kakaoLoginTapped
        case kakaoSignInResult(Result<String, KakaoSignInError>)
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

            case .loginResponse(.success):
                state.isLoading = false
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
