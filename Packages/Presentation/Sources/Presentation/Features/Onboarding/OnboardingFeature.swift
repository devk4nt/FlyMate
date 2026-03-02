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
                    title: "면접 영상을 업로드하세요",
                    description: "모의 면접 영상을 촬영하고 스터디원들과 공유하세요. 실전처럼 연습하고 객관적인 시선으로 성장할 수 있어요."
                ),
                OnboardingPage(
                    id: 1,
                    title: "타임스탬프 피드백을 받아보세요",
                    description: "영상의 특정 시점에 맞춘 정확한 피드백을 주고받으세요. 어떤 부분을 개선해야 할지 한눈에 파악할 수 있어요."
                ),
                OnboardingPage(
                    id: 2,
                    title: "함께 성장하세요",
                    description: "스터디원들과 서로 피드백을 나누며 면접 실력을 함께 키워가세요. FlyMate와 함께라면 면접이 두렵지 않아요."
                ),
            ]
        }
    }

    public enum Action {
        case pageChanged(Int)
        case skipTapped
        case startTapped
        case delegate(Delegate)

        public enum Delegate {
            case onboardingCompleted
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

            case .delegate:
                return .none
            }
        }
    }
}
