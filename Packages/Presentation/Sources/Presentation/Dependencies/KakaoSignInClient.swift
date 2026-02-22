import ComposableArchitecture
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

// MARK: - Kakao Sign In Client

public struct KakaoSignInClient: Sendable {
    public var signIn: @Sendable () async throws -> String

    public init(signIn: @escaping @Sendable () async throws -> String) {
        self.signIn = signIn
    }

    // MARK: - SDK Lifecycle

    @MainActor
    public static func initializeSDK() {
        guard let appKey = Bundle.main.infoDictionary?["KAKAO_APP_KEY"] as? String,
              !appKey.isEmpty else {
            return
        }
        KakaoSDK.initSDK(appKey: appKey)
    }

    @MainActor
    public static func handleOpenURL(_ url: URL) -> Bool {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            return AuthController.handleOpenUrl(url: url)
        }
        return false
    }
}

extension KakaoSignInClient: DependencyKey {
    public static let liveValue = KakaoSignInClient(
        signIn: { try await KakaoSignInPerformer.performSignIn() }
    )

    public static let testValue = KakaoSignInClient(
        signIn: unimplemented("\(Self.self).signIn")
    )
}

extension DependencyValues {
    public var kakaoSignInClient: KakaoSignInClient {
        get { self[KakaoSignInClient.self] }
        set { self[KakaoSignInClient.self] = newValue }
    }
}

// MARK: - Sign In Performer

@MainActor
private enum KakaoSignInPerformer {
    static func performSignIn() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, (any Error)?) -> Void = { oauthToken, error in
                if let error {
                    if let sdkError = error as? SdkError,
                       sdkError.isClientFailed,
                       sdkError.getClientError().reason == .Cancelled {
                        continuation.resume(throwing: KakaoSignInError.canceled)
                    } else {
                        continuation.resume(throwing: KakaoSignInError.failed(error.localizedDescription))
                    }
                    return
                }
                guard let accessToken = oauthToken?.accessToken else {
                    continuation.resume(throwing: KakaoSignInError.invalidToken)
                    return
                }
                continuation.resume(returning: accessToken)
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
    }
}

// MARK: - Error

public enum KakaoSignInError: Error, Equatable, LocalizedError {
    case canceled
    case invalidToken
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "로그인이 취소되었습니다."
        case .invalidToken:
            return "카카오 인증 정보를 가져올 수 없습니다."
        case .failed(let message):
            return message
        }
    }
}
