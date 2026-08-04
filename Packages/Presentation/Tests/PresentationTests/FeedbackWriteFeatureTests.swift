import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct FeedbackWriteFeatureTests {
    private let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let studyID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    @Test
    func 피드백_작성_성공() async {
        let mockFeedback = Feedback.mock

        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { _ in mockFeedback }
            $0.studyClient.fetchStudy = { _ in .mock }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.contentChanged("좋은 답변이었습니다!")) {
            $0.content = "좋은 답변이었습니다!"
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.feedbackSubmitted)
    }

    @Test
    func 피드백_작성_실패() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
            $0.studyClient.fetchStudy = { _ in .mock }
        }

        await store.send(.contentChanged("테스트 피드백")) {
            $0.content = "테스트 피드백"
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.serverError(statusCode: 500))
        }
    }

    @Test
    func 빈_내용은_제출_불가() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        // isValid가 false이므로 submitTapped은 상태 변경 없이 무시됨
        await store.send(.submitTapped)
    }

    @Test
    func 글자수_제한_적용() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        let longText = String(repeating: "가", count: 600)
        await store.send(.contentChanged(longText)) {
            $0.content = String(longText.prefix(AppConstants.maxFeedbackLength))
        }
    }

    // MARK: - Mention Tests

    @Test
    func 멤버_로드_성공() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.studyClient.fetchStudy = { _ in .mock }
        }

        await store.send(.onAppear)

        await store.receive(\.membersResponse.success) {
            $0.members = Study.mock.members
        }
    }

    @Test
    func 멤버_로드_실패() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.studyClient.fetchStudy = { _ in
                throw AppError.network(.serverError(statusCode: 500))
            }
        }

        await store.send(.onAppear)

        await store.receive(\.membersResponse.failure)
    }

    @Test
    func at_입력시_자동완성_표시() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        await store.send(.contentChanged("좋은 답변 @")) {
            $0.content = "좋은 답변 @"
        }

        await store.receive(\.mentionTriggerDetected) {
            $0.showMentionSuggestions = true
            $0.mentionQuery = ""
        }
    }

    @Test
    func at_이후_검색어_입력시_쿼리_업데이트() async {
        let store = TestStore(
            initialState: FeedbackWriteFeature.State(
                videoID: videoID,
                studyID: studyID,
                timestampSeconds: 30.0
            )
        ) {
            FeedbackWriteFeature()
        }

        await store.send(.contentChanged("@김")) {
            $0.content = "@김"
        }

        await store.receive(\.mentionTriggerDetected) {
            $0.showMentionSuggestions = true
            $0.mentionQuery = "김"
        }
    }

    @Test
    func 멤버_선택시_텍스트_치환_및_ID_추가() async {
        let member = StudyMember.mock

        var state = FeedbackWriteFeature.State(
            videoID: videoID,
            studyID: studyID,
            timestampSeconds: 30.0
        )
        state.content = "좋아요 @김"
        state.members = Study.mock.members
        state.showMentionSuggestions = true
        state.mentionQuery = "김"

        let store = TestStore(initialState: state) {
            FeedbackWriteFeature()
        }

        await store.send(.mentionSuggestionTapped(member)) {
            $0.content = "좋아요 @\(member.userName) "
            $0.mentionedUserIDs = [member.userID]
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    @Test
    func 전체_멘션시_모든_멤버_ID_추가() async {
        let members = Study.mock.members

        var state = FeedbackWriteFeature.State(
            videoID: videoID,
            studyID: studyID,
            timestampSeconds: 30.0
        )
        state.content = "확인해주세요 @"
        state.members = members
        state.showMentionSuggestions = true

        let store = TestStore(initialState: state) {
            FeedbackWriteFeature()
        }

        await store.send(.mentionAllTapped) {
            $0.content = "확인해주세요 @전체 "
            $0.mentionedUserIDs = Set(members.map(\.userID))
            $0.showMentionSuggestions = false
            $0.mentionQuery = ""
        }
    }

    @Test
    func submit시_mentionedUserIDs_전달() async {
        let member = StudyMember.mock
        let mockFeedback = Feedback.mock

        var state = FeedbackWriteFeature.State(
            videoID: videoID,
            studyID: studyID,
            timestampSeconds: 30.0
        )
        state.content = "@\(member.userName) 좋은 답변이었습니다!"
        state.mentionedUserIDs = [member.userID]

        let capturedRequest = LockIsolated<CreateFeedbackRequest?>(nil)

        let store = TestStore(initialState: state) {
            FeedbackWriteFeature()
        } withDependencies: {
            $0.feedbackClient.createFeedback = { request in
                capturedRequest.setValue(request)
                return mockFeedback
            }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }

        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }

        await store.receive(\.feedbackSubmitted)

        #expect(capturedRequest.value?.mentionedUserIDs == [member.userID])
    }
}

// MARK: - Mock Data

extension Feedback {
    static let mock = Feedback(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
        videoID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        authorID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        authorName: "테스트 유저",
        content: "좋은 답변이었습니다!",
        timestampSeconds: 30.0,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension StudyMember {
    static let mock = StudyMember(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        userName: "김테스트",
        role: .member,
        joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension Study {
    static let mock = Study(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "테스트 스터디",
        description: "테스트용 스터디입니다",
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        inviteCode: "TEST01",
        maxMembers: 6,
        members: [
            StudyMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
                userName: "김테스트",
                role: .owner,
                joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            StudyMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                userID: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
                userName: "이멤버",
                role: .member,
                joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
        ],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
