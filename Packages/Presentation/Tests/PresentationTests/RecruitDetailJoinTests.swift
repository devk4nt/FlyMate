import Testing
import Foundation
import ComposableArchitecture
import Domain
import Core
@testable import Presentation

@MainActor
struct RecruitDetailJoinTests {
    private static let viewerID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
    private static let studyID = UUID(uuidString: "00000000-0000-0000-0000-000000000700")!

    private static func linkedPost() -> RecruitPost {
        RecruitPost.mock.withStudyID(studyID)
    }

    @Test
    func 스터디방이_연결된_남의_모집글이면_신청_버튼이_보인다() {
        let state = RecruitDetailFeature.State(post: Self.linkedPost(), currentUserID: Self.viewerID)
        #expect(state.canRequestJoin)
    }

    @Test
    func 스터디방이_없는_모집글은_신청할_수_없다() {
        let state = RecruitDetailFeature.State(post: .mock, currentUserID: Self.viewerID)
        #expect(!state.canRequestJoin)
    }

    @Test
    func 마감일이_지난_모집글은_status가_recruiting이어도_신청할_수_없다() {
        let mock = RecruitPost.mock
        let post = RecruitPost(
            id: mock.id,
            title: mock.title,
            description: mock.description,
            field: mock.field,
            meetingType: mock.meetingType,
            region: mock.region,
            schedule: mock.schedule,
            startDate: mock.startDate,
            endDate: mock.endDate,
            maxMembers: mock.maxMembers,
            deadline: Date(timeIntervalSince1970: 1_000),
            requirement: mock.requirement,
            contactMethod: mock.contactMethod,
            linkURL: mock.linkURL,
            authorID: mock.authorID,
            authorName: mock.authorName,
            status: .recruiting,
            commentCount: mock.commentCount,
            createdAt: mock.createdAt
        ).withStudyID(Self.studyID)
        let state = RecruitDetailFeature.State(post: post, currentUserID: Self.viewerID)
        #expect(!state.canRequestJoin)
    }

    @Test
    func 작성자_본인에게는_신청_버튼이_없다() {
        let post = Self.linkedPost()
        let state = RecruitDetailFeature.State(post: post, currentUserID: post.authorID)
        #expect(!state.canRequestJoin)
    }

    @Test
    func 가입_신청_성공시_완료_상태와_안내_토스트() async {
        let store = TestStore(
            initialState: RecruitDetailFeature.State(
                post: Self.linkedPost(),
                currentUserID: Self.viewerID
            )
        ) {
            RecruitDetailFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudyByPost = { _ in JoinRequest.mock }
        }

        await store.send(.joinTapped) {
            $0.joinRequest = .loading
        }

        await store.receive(\.joinResponse.success) {
            $0.joinRequest = .loaded(JoinRequest.mock)
            $0.toastMessage = "가입 신청을 보냈어요. 방장이 확인하면 알림으로 알려드릴게요."
            $0.showToast = true
        }
    }

    @Test
    func 이미_신청한_스터디면_사용자_문구로_알린다() async {
        let error = AppError.business(.alreadyRequested)
        let store = TestStore(
            initialState: RecruitDetailFeature.State(
                post: Self.linkedPost(),
                currentUserID: Self.viewerID
            )
        ) {
            RecruitDetailFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudyByPost = { _ in throw error }
        }

        await store.send(.joinTapped) {
            $0.joinRequest = .loading
        }

        await store.receive(\.joinResponse.failure) {
            $0.joinRequest = .failed(error)
            $0.toastMessage = error.localizedDescription
            $0.showToast = true
        }
    }

    @Test
    func 신청_진행_중_연속_탭은_무시된다() async {
        let responseClock = TestClock()
        let store = TestStore(
            initialState: RecruitDetailFeature.State(
                post: Self.linkedPost(),
                currentUserID: Self.viewerID
            )
        ) {
            RecruitDetailFeature()
        } withDependencies: {
            // 즉시 응답하면 두 번째 탭 전에 joinResponse가 도착해 레이스가 난다 — 클록으로 응답 시점 제어
            $0.studyClient.requestJoinStudyByPost = { _ in
                try await responseClock.sleep(for: .seconds(1))
                return JoinRequest.mock
            }
        }

        await store.send(.joinTapped) {
            $0.joinRequest = .loading
        }
        // 로딩 중에는 상태 변화도 추가 요청도 없어야 한다
        await store.send(.joinTapped)

        await responseClock.advance(by: .seconds(1))

        await store.receive(\.joinResponse.success) {
            $0.joinRequest = .loaded(JoinRequest.mock)
            $0.toastMessage = "가입 신청을 보냈어요. 방장이 확인하면 알림으로 알려드릴게요."
            $0.showToast = true
        }
    }
}
