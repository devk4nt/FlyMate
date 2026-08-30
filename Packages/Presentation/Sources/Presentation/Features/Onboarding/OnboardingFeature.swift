import Foundation
import ComposableArchitecture

// MARK: - Data Model

public struct OnboardingPage: Equatable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let description: String
}

// MARK: - Feature

@Reducer
public struct OnboardingFeature: Sendable {
    private enum Constants {
        static let onboardingCompletedKey = "hasCompletedOnboarding"
    }

    @ObservableState
    public struct State: Equatable {
        public var currentPage: Int
        public var pages: [OnboardingPage]

        public var isLastPage: Bool {
            currentPage == pages.count - 1
        }

        public init() {
            self.currentPage = 0
            self.pages = [
                OnboardingPage(
                    id: 0,
                    title: "면접 영상을 올려보세요",
                    description: "모의 면접 영상을 스터디원과 공유하고 객관적인 시선으로 연습해요."
                ),
                OnboardingPage(
                    id: 1,
                    title: "필요한 순간에 피드백을 받아요",
                    description: "영상 속 정확한 시점에 의견을 남겨 개선할 부분을 빠르게 확인해요."
                ),
                OnboardingPage(
                    id: 2,
                    title: "서로 돕고 함께 성장해요",
                    description: "멤버의 활동과 응원을 확인하고 서로 피드백을 주고받아요."
                ),
                OnboardingPage(
                    id: 3,
                    title: "알림을 켜주세요",
                    description: "스터디 가입 신청과 승인, 내 영상에 달린 피드백, 나를 언급한 멘션을 놓치지 않으려면 알림이 꼭 필요해요."
                ),
                OnboardingPage(
                    id: 4,
                    title: "첫 영상을 올려보세요",
                    description: "짧은 연습 영상을 올리면 다른 사람들이 피드백을 남겨줘요."
                ),
            ]
        }

        /// 알림 권한 어필 페이지 — CTA가 시스템 권한 팝업을 띄운다
        public var isNotificationPage: Bool {
            currentPage == OnboardingFeature.notificationPageID
        }
    }

    public static let notificationPageID = 3

    public enum Action {
        case pageChanged(Int)
        case skipTapped
        case startTapped
        case enableNotificationsTapped
        case uploadFirstVideoTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case onboardingCompleted
            case firstUploadRequested
            case notificationPermissionRequested
        }
    }

    @Dependency(\.userDefaultsClient) private var userDefaultsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .pageChanged(let page):
                state.currentPage = page
                return .none

            case .skipTapped:
                let client = userDefaultsClient
                return .run { send in
                    await client.setBool(true, Constants.onboardingCompletedKey)
                    await send(.delegate(.onboardingCompleted))
                }

            case .startTapped:
                let client = userDefaultsClient
                return .run { send in
                    await client.setBool(true, Constants.onboardingCompletedKey)
                    await send(.delegate(.onboardingCompleted))
                }

            case .enableNotificationsTapped:
                // 시스템 팝업은 부모(AppFeature)가 띄우고, 온보딩은 다음 페이지로 진행
                state.currentPage = min(state.currentPage + 1, state.pages.count - 1)
                return .send(.delegate(.notificationPermissionRequested))

            case .uploadFirstVideoTapped:
                let client = userDefaultsClient
                return .run { send in
                    await client.setBool(true, Constants.onboardingCompletedKey)
                    await send(.delegate(.firstUploadRequested))
                }

            case .delegate:
                return .none
            }
        }
    }
}
