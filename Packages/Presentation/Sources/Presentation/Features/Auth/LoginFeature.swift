import Foundation
import ComposableArchitecture
import Core
import Domain

@Reducer
public struct LoginFeature {
    /// 이메일 로그인 시트를 여는 히든 제스처의 로고 탭 횟수 (App Store 심사용)
    public static let hiddenLoginTapThreshold = 5
    /// Staging 테스트 계정 피커를 여는 로고 탭 횟수 — staging 빌드에서만 동작
    public static let stagingLoginTapThreshold = 2

    /// Secrets.staging.xcconfig → Info.plist로 주입되는 테스트 계정 비밀번호.
    /// prod 빌드(Secrets.xcconfig)에는 값이 없어 nil이 되고, 테스트 계정 로그인이 비활성화된다.
    public static var stagingTestPassword: String? {
        guard let password = Bundle.main.infoDictionary?["STAGING_TEST_PASSWORD"] as? String,
              !password.isEmpty else { return nil }
        return password
    }

    /// seed-staging.mjs가 만드는 스테이징 테스트 계정 (스킴 FlyMate-Owner/Member/Applicant와 동일)
    public enum StagingAccount: String, CaseIterable, Equatable, Sendable {
        case owner
        case member
        case applicant

        public var email: String {
            switch self {
            case .owner: "test@flymate.app"
            case .member: "test2@flymate.app"
            case .applicant: "test3@flymate.app"
            }
        }

        public var title: String {
            switch self {
            case .owner: "방장 (김하늘)"
            case .member: "멤버 (이수민)"
            case .applicant: "신청자 (박지원)"
            }
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var error: AppError?
        public var logoTapCount = 0
        public var showsEmailLogin = false
        public var email = ""
        public var password = ""
        public var showsStagingAccountPicker = false
        /// nil이면 테스트 계정 로그인 비활성 — 테스트에서 주입 가능하도록 State에 둔다
        public let stagingTestPassword: String?

        public init(stagingTestPassword: String? = LoginFeature.stagingTestPassword) {
            self.stagingTestPassword = stagingTestPassword
        }
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
        case stagingAccountSelected(StagingAccount)
        case stagingAccountPickerDismissed
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
                // staging 빌드: 2탭에서 테스트 계정 피커가 먼저 열리므로 5탭 이메일 시트는 도달 불가 (필요 없음)
                if state.stagingTestPassword != nil,
                   state.logoTapCount >= Self.stagingLoginTapThreshold {
                    state.logoTapCount = 0
                    state.showsStagingAccountPicker = true
                    return .none
                }
                guard state.logoTapCount >= Self.hiddenLoginTapThreshold else { return .none }
                state.logoTapCount = 0
                state.showsEmailLogin = true
                return .none

            case .stagingAccountSelected(let account):
                guard let password = state.stagingTestPassword else { return .none }
                state.showsStagingAccountPicker = false
                state.isLoading = true
                state.error = nil
                let client = authClient
                let email = account.email
                return .run { send in
                    do {
                        let user = try await client.signInWithEmail(email, password)
                        await send(.loginResponse(.success(user)))
                    } catch {
                        let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                        await send(.loginResponse(.failure(appError)))
                    }
                }

            case .stagingAccountPickerDismissed:
                state.showsStagingAccountPicker = false
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
