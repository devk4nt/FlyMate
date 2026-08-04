import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct JoinStudyFeatureTests {
    @Test
    func 초대코드_입력시_대문자_변환() async {
        let store = TestStore(initialState: JoinStudyFeature.State()) {
            JoinStudyFeature()
        }

        await store.send(.inviteCodeChanged("abc123")) {
            $0.inviteCode = "ABC123"
        }
    }

    @Test
    func 초대코드_최대_길이_제한() async {
        let store = TestStore(initialState: JoinStudyFeature.State()) {
            JoinStudyFeature()
        }

        await store.send(.inviteCodeChanged("ABCDEFGH")) {
            $0.inviteCode = "ABCDEF"
        }
    }

    @Test
    func 코드_입력시_에러메시지_초기화() async {
        var state = JoinStudyFeature.State()
        state.errorMessage = "유효하지 않은 초대 코드입니다."

        let store = TestStore(initialState: state) {
            JoinStudyFeature()
        }

        await store.send(.inviteCodeChanged("A")) {
            $0.inviteCode = "A"
            $0.errorMessage = nil
        }
    }

    @Test
    func 유효하지_않은_코드로_참여_시도시_무시() async {
        var state = JoinStudyFeature.State()
        state.inviteCode = "ABC" // 3자리 — 6자리 미만

        let store = TestStore(initialState: state) {
            JoinStudyFeature()
        }

        // isCodeValid == false이므로 상태 변경 없이 무시
        await store.send(.joinTapped)
    }

    @Test
    func 참여_요청_성공() async {
        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "ABC123")
        ) {
            JoinStudyFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudy = { _ in JoinRequest.mock }
        }

        await store.send(.joinTapped) {
            $0.joinState = .loading
        }

        await store.receive(\.requestResponse.success) {
            $0.joinState = .loaded(JoinRequest.mock)
        }
    }

    @Test
    func 참여_요청_성공후_확인_탭시_delegate() async {
        var state = JoinStudyFeature.State(inviteCode: "ABC123")
        state.joinState = .loaded(JoinRequest.mock)

        let store = TestStore(initialState: state) {
            JoinStudyFeature()
        }

        await store.send(.confirmTapped)
        await store.receive(\.delegate.joinRequested)
    }

    @Test
    func 참여_요청_실패_유효하지_않은_코드() async {
        let error = AppError.business(.invalidInviteCode)

        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "WRONG1")
        ) {
            JoinStudyFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudy = { _ in throw error }
        }

        await store.send(.joinTapped) {
            $0.joinState = .loading
        }

        await store.receive(\.requestResponse.failure) {
            $0.joinState = .failed(error)
            $0.errorMessage = "유효하지 않은 초대 코드입니다."
        }
    }

    @Test
    func 참여_요청_실패_이미_참여중() async {
        let error = AppError.business(.alreadyJoined)

        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "ABC123")
        ) {
            JoinStudyFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudy = { _ in throw error }
        }

        await store.send(.joinTapped) {
            $0.joinState = .loading
        }

        await store.receive(\.requestResponse.failure) {
            $0.joinState = .failed(error)
            $0.errorMessage = "이미 참여 중인 스터디입니다."
        }
    }

    @Test
    func 참여_요청_실패_이미_요청함() async {
        let error = AppError.business(.alreadyRequested)

        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "ABC123")
        ) {
            JoinStudyFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudy = { _ in throw error }
        }

        await store.send(.joinTapped) {
            $0.joinState = .loading
        }

        await store.receive(\.requestResponse.failure) {
            $0.joinState = .failed(error)
            $0.errorMessage = "이미 참여 요청을 보낸 스터디입니다."
        }
    }

    @Test
    func 참여_요청_실패_인원_초과() async {
        let error = AppError.business(.studyFull)

        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "ABC123")
        ) {
            JoinStudyFeature()
        } withDependencies: {
            $0.studyClient.requestJoinStudy = { _ in throw error }
        }

        await store.send(.joinTapped) {
            $0.joinState = .loading
        }

        await store.receive(\.requestResponse.failure) {
            $0.joinState = .failed(error)
            $0.errorMessage = "스터디 인원이 가득 찼습니다."
        }
    }

    @Test
    func 취소_탭시_dismiss() async {
        let store = TestStore(initialState: JoinStudyFeature.State()) {
            JoinStudyFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { }
        }

        await store.send(.cancelTapped)
    }

    @Test
    func 딥링크_초대코드_프리필() async {
        let store = TestStore(
            initialState: JoinStudyFeature.State(inviteCode: "TEST01")
        ) {
            JoinStudyFeature()
        }

        // 초기 상태에서 코드가 프리필되어 있고 유효함
        #expect(store.state.inviteCode == "TEST01")
        #expect(store.state.isCodeValid == true)
    }
}

// MARK: - Mock Data

extension JoinRequest {
    static let mock = JoinRequest(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000050")!,
        studyID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        studyName: "iOS 면접 스터디",
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        userName: "테스트 유저",
        status: .pending,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
