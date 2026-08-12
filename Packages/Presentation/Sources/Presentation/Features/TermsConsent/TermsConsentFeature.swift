import Foundation
import ComposableArchitecture

/// 이용약관 및 커뮤니티 가이드라인 동의 (App Store Guideline 1.2 — UGC 앱 필수).
/// 로그인 후 최초 1회, 부적절 콘텐츠 무관용 정책에 동의해야 서비스를 이용할 수 있다.
@Reducer
public struct TermsConsentFeature: Sendable {
    /// UserDefaults 키 — AppFeature에서 동의 여부 확인에 사용
    public static let consentKey = "hasAgreedToTerms"

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case agreeTapped
        case delegate(Delegate)

        public enum Delegate {
            case consented
        }
    }

    @Dependency(\.userDefaultsClient) private var userDefaultsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .agreeTapped:
                let client = userDefaultsClient
                return .run { send in
                    await client.setBool(true, Self.consentKey)
                    await send(.delegate(.consented))
                }

            case .delegate:
                return .none
            }
        }
    }
}
