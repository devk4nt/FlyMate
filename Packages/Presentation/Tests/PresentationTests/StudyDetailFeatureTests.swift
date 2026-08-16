import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct StudyDetailFeatureTests {
    private nonisolated static let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private nonisolated static let memberID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // MARK: - onAppear

    @Test
    func onAppear_영상_로드_성공_멤버는_대기요청_조회_안함() async {
        let videos = [Video.detailMock(index: 0)]

        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, _ in videos }
        }

        await store.send(.onAppear) {
            $0.videos = .loading
        }

        await store.receive(\.videosResponse.success) {
            $0.videos = .loaded(videos)
            $0.videosPagination.items = videos
            $0.videosPagination.cursor = videos.last?.createdAt
            $0.videosPagination.hasMore = false // 1개 < defaultPageSize(20)
        }
    }

    @Test
    func onAppear_방장이면_대기중_요청_수도_로드() async {
        let videos = [Video.detailMock(index: 0)]

        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, _ in videos }
            $0.studyClient.fetchPendingRequests = { _ in [.detailMock] }
        }

        await store.send(.onAppear) {
            $0.videos = .loading
        }

        await store.receive(\.videosResponse.success) {
            $0.videos = .loaded(videos)
            $0.videosPagination.items = videos
            $0.videosPagination.cursor = videos.last?.createdAt
            $0.videosPagination.hasMore = false
        }

        await store.receive(\.pendingRequestCountResponse.success) {
            $0.pendingRequestCount = 1
        }
    }

    @Test
    func onAppear_영상_로드_실패() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, _ in throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear) {
            $0.videos = .loading
        }

        await store.receive(\.videosResponse.failure) {
            $0.videos = .failed(.network(.noConnection))
        }
    }

    @Test
    func onAppear_이미_로드된_상태면_재요청_안함() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        state.videos = .loaded([])

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.onAppear)
    }

    // MARK: - Refresh

    @Test
    func 새로고침시_영상_다시_로드_및_초대코드_정보_초기화() async {
        let videos = [Video.detailMock(index: 0)]

        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        state.videos = .loaded(videos)
        state.inviteCodeInfo = .loaded(.detailMock)

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, _ in videos }
        }

        // 로드된 영상 목록은 유지 — 스켈레톤으로 돌아가지 않는다
        await store.send(.refresh) {
            $0.inviteCodeInfo = .idle
        }

        await store.receive(\.videosResponse.success) {
            $0.videos = .loaded(videos)
            $0.videosPagination.items = videos
            $0.videosPagination.cursor = videos.last?.createdAt
            $0.videosPagination.hasMore = false
        }
    }

    // MARK: - Pagination

    @Test
    func 페이지네이션_한페이지_가득차면_hasMore_유지_loadMore로_추가_로드() async {
        let page1 = (0..<AppConstants.defaultPageSize).map { Video.detailMock(index: $0) }
        let page2 = [Video.detailMock(index: 20), Video.detailMock(index: 21)]

        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, cursor in cursor == nil ? page1 : page2 }
        }

        await store.send(.onAppear) {
            $0.videos = .loading
        }

        await store.receive(\.videosResponse.success) {
            $0.videos = .loaded(page1)
            $0.videosPagination.items = page1
            $0.videosPagination.cursor = page1.last?.createdAt
            $0.videosPagination.hasMore = true // 20개 == defaultPageSize
        }

        await store.send(.loadMoreVideos) {
            $0.videosPagination.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.success) {
            $0.videosPagination.isLoadingMore = false
            $0.videosPagination.items = page1 + page2
            $0.videosPagination.cursor = page2.last?.createdAt
            $0.videosPagination.hasMore = false // 2개 < defaultPageSize
            $0.videos = .loaded(page1 + page2)
        }
    }

    @Test
    func loadMore_hasMore_없으면_무시() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        state.videosPagination.hasMore = false

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.loadMoreVideos)
    }

    @Test
    func loadMore_이미_로딩중이면_무시() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        state.videosPagination.isLoadingMore = true

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.loadMoreVideos)
    }

    @Test
    func loadMore_실패시_로딩_플래그만_해제() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.videoClient.fetchVideos = { _, _ in throw AppError.network(.timeout) }
        }

        await store.send(.loadMoreVideos) {
            $0.videosPagination.isLoadingMore = true
        }

        await store.receive(\.loadMoreResponse.failure) {
            $0.videosPagination.isLoadingMore = false
        }
    }

    // MARK: - Notice (방장 권한)

    @Test
    func 방장이_공지_탭하면_편집모드_진입() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        ) {
            StudyDetailFeature()
        }

        await store.send(.noticeTapped) {
            $0.editingNoticeText = "기존 공지"
            $0.isEditingNotice = true
        }
    }

    @Test
    func 멤버가_공지_탭하면_무시() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.memberID)
        ) {
            StudyDetailFeature()
        }

        await store.send(.noticeTapped)
    }

    @Test
    func 공지_저장_성공() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.isEditingNotice = true

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        } withDependencies: {
            $0.studyClient.updateNotice = { _, _ in }
        }

        await store.send(.editingNoticeTextChanged("  새 공지  ")) {
            $0.editingNoticeText = "  새 공지  "
        }

        await store.send(.saveNoticeTapped) {
            $0.noticeUpdateState = .loading
        }

        // noticeUpdatedAt이 Reducer 내부의 Date()로 설정되어 값을 예측할 수 없으므로 비완전 검증
        store.exhaustivity = .off
        await store.receive(\.noticeUpdateResponse.success)
        #expect(store.state.study.notice == "새 공지")
        #expect(store.state.study.noticeUpdatedAt != nil)
        #expect(store.state.noticeUpdateState == .idle)
        #expect(store.state.isEditingNotice == false)
        #expect(store.state.editingNoticeText.isEmpty)
    }

    @Test
    func 공지_빈문자열_저장_무시() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.isEditingNotice = true
        state.editingNoticeText = "   "

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.saveNoticeTapped)
    }

    @Test
    func 공지_삭제_성공() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.isEditingNotice = true
        state.editingNoticeText = "기존 공지"

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        } withDependencies: {
            $0.studyClient.updateNotice = { _, notice in
                #expect(notice == nil)
            }
        }

        await store.send(.deleteNoticeTapped) {
            $0.noticeUpdateState = .loading
        }

        await store.receive(\.noticeUpdateResponse.success) {
            $0.study.notice = nil
            $0.study.noticeUpdatedAt = nil
            $0.noticeUpdateState = .idle
            $0.isEditingNotice = false
            $0.editingNoticeText = ""
        }
    }

    @Test
    func 공지_저장_실패() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.isEditingNotice = true
        state.editingNoticeText = "새 공지"

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        } withDependencies: {
            $0.studyClient.updateNotice = { _, _ in throw AppError.business(.unauthorized) }
        }

        await store.send(.saveNoticeTapped) {
            $0.noticeUpdateState = .loading
        }

        await store.receive(\.noticeUpdateResponse.failure) {
            $0.noticeUpdateState = .failed(.business(.unauthorized))
        }
    }

    @Test
    func 공지_편집기_닫기() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.isEditingNotice = true
        state.editingNoticeText = "작성 중"
        state.noticeUpdateState = .failed(.network(.timeout))

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.dismissNoticeEditor) {
            $0.isEditingNotice = false
            $0.editingNoticeText = ""
            $0.noticeUpdateState = .idle
        }
    }

    // MARK: - Invite Code Info

    @Test
    func 초대코드_정보_조회_성공() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.studyClient.fetchInviteCodeInfo = { _ in .detailMock }
        }

        await store.send(.inviteCodeInfoTapped) {
            $0.isInviteCodePopoverPresented = true
            $0.inviteCodeInfo = .loading
        }

        await store.receive(\.inviteCodeInfoResponse.success) {
            $0.inviteCodeInfo = .loaded(.detailMock)
        }

        await store.send(.dismissInviteCodePopover) {
            $0.isInviteCodePopoverPresented = false
        }
    }

    @Test
    func 초대코드_정보_로드됨_상태면_재조회_안함() async {
        var state = StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        state.inviteCodeInfo = .loaded(.detailMock)

        let store = TestStore(initialState: state) {
            StudyDetailFeature()
        }

        await store.send(.inviteCodeInfoTapped) {
            $0.isInviteCodePopoverPresented = true
        }
    }

    @Test
    func 초대코드_정보_조회_실패() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        ) {
            StudyDetailFeature()
        } withDependencies: {
            $0.studyClient.fetchInviteCodeInfo = { _ in throw AppError.network(.serverError(statusCode: 500)) }
        }

        await store.send(.inviteCodeInfoTapped) {
            $0.isInviteCodePopoverPresented = true
            $0.inviteCodeInfo = .loading
        }

        await store.receive(\.inviteCodeInfoResponse.failure) {
            $0.inviteCodeInfo = .failed(.network(.serverError(statusCode: 500)))
        }
    }

    // MARK: - 부모 위임 액션

    @Test
    func 부모_처리_액션은_상태변경_없음() async {
        let store = TestStore(
            initialState: StudyDetailFeature.State(study: .detailMock, currentUserID: Self.ownerID)
        ) {
            StudyDetailFeature()
        }

        await store.send(.videoTapped(Video.detailMock(index: 0)))
        await store.send(.uploadVideoTapped(studyID: Study.detailMock.id))
        await store.send(.memberManagementTapped)
        await store.send(.joinRequestManagementTapped)
    }
}

// MARK: - Mock Data

private extension Study {
    static let detailMock = Study(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        name: "승무원 면접 스터디",
        description: "영상 피드백 스터디",
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        inviteCode: "FLY123",
        maxMembers: 8,
        members: [],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        notice: "기존 공지",
        noticeUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

private extension Video {
    static func detailMock(index: Int) -> Video {
        Video(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-0000000001%02d", index))!,
            studyID: Study.detailMock.id,
            uploaderID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            uploaderName: "김지원",
            title: "기내방송 연습 \(index)",
            videoURL: URL(string: "https://example.com/video\(index).mp4")!,
            durationSeconds: 120,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 - TimeInterval(index * 60))
        )
    }
}

private extension InviteCode {
    static let detailMock = InviteCode(
        code: "FLY123",
        studyID: Study.detailMock.id,
        studyName: "승무원 면접 스터디",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        expiresAt: Date(timeIntervalSince1970: 4_100_000_000),
        isActive: true
    )
}

private extension JoinRequest {
    static let detailMock = JoinRequest(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
        studyID: Study.detailMock.id,
        studyName: "승무원 면접 스터디",
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        userName: "이수현",
        status: .pending,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
