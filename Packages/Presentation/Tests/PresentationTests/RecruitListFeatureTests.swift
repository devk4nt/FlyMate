import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct RecruitListFeatureTests {
    private static let userID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!

    @Test
    func 모집글_목록_로딩_성공() async {
        let mockPosts = [RecruitPost.mock]

        let store = TestStore(initialState: RecruitListFeature.State(currentUserID: Self.userID)) {
            RecruitListFeature()
        } withDependencies: {
            $0.recruitClient.fetchPosts = { _, _ in mockPosts }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }
        await store.receive(\.postsResponse.success) {
            $0.posts.items = mockPosts
            $0.posts.cursor = mockPosts.last?.createdAt
            $0.posts.hasMore = false
            $0.loadingState = .loaded(mockPosts)
        }
    }

    @Test
    func 모집글_목록_로딩_실패() async {
        let store = TestStore(initialState: RecruitListFeature.State(currentUserID: Self.userID)) {
            RecruitListFeature()
        } withDependencies: {
            $0.recruitClient.fetchPosts = { _, _ in throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear) {
            $0.loadingState = .loading
        }
        await store.receive(\.postsResponse.failure) {
            $0.loadingState = .failed(.network(.noConnection))
        }
    }

    @Test
    func 모집중_필터_토글시_재조회() async {
        let store = TestStore(initialState: RecruitListFeature.State(currentUserID: Self.userID)) {
            RecruitListFeature()
        } withDependencies: {
            $0.recruitClient.fetchPosts = { filter, _ in
                filter.recruitingOnly ? [] : [RecruitPost.mock]
            }
        }

        await store.send(.recruitingOnlyToggled) {
            $0.filter.recruitingOnly = true
        }
        await store.receive(\.refresh) {
            $0.loadingState = .loading
        }
        await store.receive(\.postsResponse.success) {
            $0.posts.items = []
            $0.posts.hasMore = false
            $0.loadingState = .loaded([])
        }
    }

    @Test
    func 모집글_탭시_상세_이동() async {
        let post = RecruitPost.mock

        let store = TestStore(initialState: RecruitListFeature.State(currentUserID: Self.userID)) {
            RecruitListFeature()
        }

        await store.send(.postTapped(post)) {
            $0.detail = RecruitDetailFeature.State(post: post, currentUserID: Self.userID)
        }
    }
}

// MARK: - Mock

extension RecruitPost {
    static let mock = RecruitPost(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000600")!,
        title: "국내 항공사 영상면접 스터디원 모집",
        description: "매주 영상 촬영하고 상호 피드백해요.",
        field: .flightAttendant,
        meetingType: .online,
        region: nil,
        schedule: "매주 화·목 20시",
        startDate: Date(timeIntervalSince1970: 1_900_000_000),
        endDate: nil,
        maxMembers: 6,
        deadline: Date(timeIntervalSince1970: 1_899_000_000),
        requirement: "주 1회 영상 업로드 가능",
        contactMethod: "댓글로 문의해주세요",
        linkURL: nil,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        authorName: "김하늘",
        status: .recruiting,
        commentCount: 0,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}
