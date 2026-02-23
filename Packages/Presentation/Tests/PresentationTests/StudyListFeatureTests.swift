import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct StudyListFeatureTests {
    @Test
    func 스터디_목록_로딩_성공() async {
        let mockStudies = [Study.mock]

        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { mockStudies }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
        }
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded(mockStudies)
        }
    }

    @Test
    func 스터디_목록_로딩_실패() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { throw AppError.network(.noConnection) }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
        }
        await store.receive(\.studiesResponse.failure) {
            $0.studies = .failed(.network(.noConnection))
        }
    }

    @Test
    func 스터디_생성_시트_표시() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.createStudyTapped) {
            $0.createStudy = StudyCreateFeature.State()
        }
    }

    @Test
    func 참여_시트_표시() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.joinStudyTapped) {
            $0.joinStudy = JoinStudyFeature.State()
        }
    }

    @Test
    func 초대코드로_참여_시트_프리필() async {
        let store = TestStore(initialState: StudyListFeature.State()) {
            StudyListFeature()
        }

        await store.send(.showJoinStudy(inviteCode: "TEST01")) {
            $0.joinStudy = JoinStudyFeature.State(inviteCode: "TEST01")
        }
    }

    @Test
    func 참여_성공시_시트_닫고_새로고침() async {
        var state = StudyListFeature.State()
        state.joinStudy = JoinStudyFeature.State(inviteCode: "ABC123")

        let store = TestStore(initialState: state) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [Study.mock] }
        }

        await store.send(.joinStudy(.presented(.delegate(.studyJoined(Study.mock))))) {
            $0.joinStudy = nil
        }

        await store.receive(\.refresh) {
            $0.studies = .loading
        }

        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded([Study.mock])
        }
    }

    @Test
    func 새로고침시_목록_다시_로딩() async {
        var state = StudyListFeature.State()
        state.studies = .loaded([Study.mock])

        let store = TestStore(initialState: state) {
            StudyListFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [Study.mock] }
        }

        await store.send(.refresh) {
            $0.studies = .loading
        }
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded([Study.mock])
        }
    }
}

// MARK: - Mock Data

extension Study {
    static let mock = Study(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "iOS 면접 스터디",
        description: "매주 모의 면접을 진행하는 스터디입니다.",
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        inviteCode: "ABC123",
        maxMembers: 8,
        members: [.mockOwner],
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

extension StudyMember {
    static let mockOwner = StudyMember(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        userName: "테스트 유저",
        role: .owner,
        joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
