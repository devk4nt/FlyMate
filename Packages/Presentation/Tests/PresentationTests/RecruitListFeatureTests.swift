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

    // MARK: - 사용자 차단 (Guideline 1.2)

    @Test
    func 모집글_작성자_차단시_댓글_즉시_제거_및_delegate_전달() async {
        let blockedAuthorID = RecruitPost.mock.authorID
        let otherAuthorID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let blockedComment = RecruitComment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000701")!,
            postID: RecruitPost.mock.id,
            parentID: nil,
            authorID: blockedAuthorID,
            authorName: "김하늘",
            authorProfileURL: nil,
            content: "참여하고 싶어요",
            createdAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        let otherComment = RecruitComment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000702")!,
            postID: RecruitPost.mock.id,
            parentID: nil,
            authorID: otherAuthorID,
            authorName: "박구름",
            authorProfileURL: nil,
            content: "저도 문의드려요",
            createdAt: Date(timeIntervalSince1970: 1_800_000_200)
        )

        var state = RecruitDetailFeature.State(post: .mock, currentUserID: Self.userID)
        state.comments = .loaded([blockedComment, otherComment])

        let blocked = LockIsolated<(UUID, String)?>(nil)
        let store = TestStore(initialState: state) {
            RecruitDetailFeature()
        } withDependencies: {
            $0.blockClient.blockUser = { userID, userName in blocked.setValue((userID, userName)) }
        }

        await store.send(.blockUserTapped(authorID: blockedAuthorID, authorName: "김하늘")) {
            $0.blockAlert = AlertState {
                TextState("김하늘님을 차단할까요?")
            } actions: {
                ButtonState(role: .destructive, action: .confirmBlock(userID: blockedAuthorID, userName: "김하늘")) {
                    TextState("차단하기")
                }
                ButtonState(role: .cancel) {
                    TextState("취소")
                }
            } message: {
                TextState("차단한 사용자의 모집 글과 댓글이 더 이상 보이지 않아요. 설정 > 차단한 사용자에서 해제할 수 있어요.")
            }
        }

        await store.send(.blockAlert(.presented(.confirmBlock(userID: blockedAuthorID, userName: "김하늘")))) {
            $0.blockAlert = nil
        }

        await store.receive(\.blockResponse.success) {
            $0.comments = .loaded([otherComment])
        }

        await store.receive(\.delegate.userBlocked)

        #expect(blocked.value?.0 == blockedAuthorID)
        #expect(blocked.value?.1 == "김하늘")
    }

    @Test
    func 차단_delegate_수신시_목록에서_해당_작성자_글_제거_및_상세_닫힘() async {
        let blockedAuthorID = RecruitPost.mock.authorID
        var state = RecruitListFeature.State(currentUserID: Self.userID)
        state.posts.items = [RecruitPost.mock]
        state.loadingState = .loaded([RecruitPost.mock])
        state.detail = RecruitDetailFeature.State(post: .mock, currentUserID: Self.userID)

        let store = TestStore(initialState: state) {
            RecruitListFeature()
        }

        await store.send(.detail(.presented(.delegate(.userBlocked(blockedAuthorID))))) {
            $0.detail = nil
            $0.posts.items = []
            $0.loadingState = .loaded([])
            $0.toastMessage = "사용자를 차단했습니다"
            $0.showToast = true
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
