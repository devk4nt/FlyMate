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
                    title: "첫 영상을 올려보세요",
                    description: "짧은 연습 영상을 올리면 다른 사람들이 피드백을 남겨줘요."
                ),
            ]
        }
    }

    public enum Action {
        case pageChanged(Int)
        case skipTapped
        case startTapped
        case uploadFirstVideoTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate {
            case onboardingCompleted
            case firstUploadRequested
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
