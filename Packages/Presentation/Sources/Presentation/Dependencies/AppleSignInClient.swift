import AuthenticationServices
import ComposableArchitecture
import CryptoKit
import Foundation

// MARK: - Apple Sign In Result

public struct AppleSignInResult: Equatable, Sendable {
    public let idToken: String
    public let nonce: String
    public let fullName: PersonNameComponents?
    public let email: String?
}

// MARK: - Apple Sign In Client

public struct AppleSignInClient: Sendable {
    public var signIn: @Sendable () async throws -> AppleSignInResult

    public init(signIn: @escaping @Sendable () async throws -> AppleSignInResult) {
        self.signIn = signIn
    }
}

extension AppleSignInClient: DependencyKey {
    public static let liveValue = AppleSignInClient(
        signIn: { try await AppleSignInDelegate.performSignIn() }
    )

    public static let testValue = AppleSignInClient(
        signIn: unimplemented("\(Self.self).signIn")
    )
}

extension DependencyValues {
    public var appleSignInClient: AppleSignInClient {
        get { self[AppleSignInClient.self] }
        set { self[AppleSignInClient.self] = newValue }
    }
}

// MARK: - ASAuthorizationController Delegate Wrapper

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, Sendable {
    private let continuation: CheckedContinuation<AppleSignInResult, any Error>
    private let nonce: String

    init(continuation: CheckedContinuation<AppleSignInResult, any Error>, nonce: String) {
        self.continuation = continuation
        self.nonce = nonce
    }

    @MainActor
    static func performSignIn() async throws -> AppleSignInResult {
        let nonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation, nonce: nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate

            // delegate를 controller가 해제되기 전까지 유지
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            continuation.resume(throwing: AppleSignInError.invalidCredential)
            return
        }

        let result = AppleSignInResult(
            idToken: idToken,
            nonce: nonce,
            fullName: credential.fullName,
            email: credential.email
        )
        continuation.resume(returning: result)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            continuation.resume(throwing: AppleSignInError.canceled)
        } else {
            continuation.resume(throwing: AppleSignInError.failed(error.localizedDescription))
        }
    }

    // MARK: - Nonce Utilities

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess, "Unable to generate nonce")
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Error

public enum AppleSignInError: Error, Equatable, LocalizedError {
    case canceled
    case invalidCredential
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "로그인이 취소되었습니다."
        case .invalidCredential:
            return "Apple 인증 정보를 가져올 수 없습니다."
        case .failed(let message):
            return message
        }
    }
}
