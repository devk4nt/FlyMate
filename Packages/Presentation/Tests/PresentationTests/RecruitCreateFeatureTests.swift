import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct RecruitCreateFeatureTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func validState() -> RecruitCreateFeature.State {
        var state = RecruitCreateFeature.State(mode: .create, now: now)
        state.title = "승무원 스터디원 모집"
        state.description = "함께 영상면접을 준비해요."
        state.field = .flightAttendant
        state.schedule = "매주 화 20시"
        state.requirement = "주 1회 참여 가능"
        state.contactMethod = "댓글로 문의"
        return state
    }

    @Test
    func 필수값_검증() {
        var state = RecruitCreateFeature.State(mode: .create, now: Self.now)
        #expect(!state.isValid)

        state = Self.validState()
        #expect(state.isValid)

        // 오프라인인데 지역 미입력이면 무효
        state.meetingType = .offline
        #expect(!state.isValid)
        state.region = "서울"
        #expect(state.isValid)

        // 마감일이 시작일보다 늦으면 무효
        state.deadline = state.startDate.addingTimeInterval(86_400)
        #expect(!state.isValid)
        state.deadline = state.startDate
        #expect(state.isValid)

        // http(s)가 아닌 링크는 무효
        state.linkText = "ftp://example.com"
        #expect(!state.isValid)
        state.linkText = "https://open.kakao.com/o/abc"
        #expect(state.isValid)
    }

    @Test
    func 등록_성공시_델리게이트_전달() async {
        let created = RecruitPost.mock
        let state = Self.validState()

        let store = TestStore(initialState: state) {
            RecruitCreateFeature()
        } withDependencies: {
            $0.recruitClient.createPost = { _ in created }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.submitResponse.success) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.saved)
    }

    @Test
    func 등록_실패시_입력_유지_및_에러_표시() async {
        let state = Self.validState()

        let store = TestStore(initialState: state) {
            RecruitCreateFeature()
        } withDependencies: {
            $0.recruitClient.createPost = { _ in throw AppError.network(.timeout) }
        }

        await store.send(.submitTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.submitResponse.failure) {
            $0.isSubmitting = false
            $0.error = .network(.timeout)
        }
        // 입력 내용은 그대로 유지되어 재시도 가능
        #expect(store.state.title == "승무원 스터디원 모집")
    }
}
