import Foundation
import Testing
import ComposableArchitecture
import Domain
import Core

@testable import Presentation

@MainActor
struct StudyManagementFeatureTests {
    @Test
    func 재진입_시_스켈레톤_재노출_방지() async {
        let mockStudies = [Study.mock]

        let store = TestStore(initialState: StudyManagementFeature.State()) {
            StudyManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { mockStudies }
        }

        await store.send(.onAppear) {
            $0.studies = .loading
        }
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded(mockStudies)
        }

        // 로드된 상태에서 onAppear 재수신 — 로딩으로 되돌리지 않고 조용히 갱신
        await store.send(.onAppear)
        await store.receive(\.studiesResponse.success)
    }

    @Test
    func 리프레시_시_기존_콘텐츠_유지() async {
        let mockStudies = [Study.mock]

        var initialState = StudyManagementFeature.State()
        initialState.studies = .loaded(mockStudies)

        let store = TestStore(initialState: initialState) {
            StudyManagementFeature()
        } withDependencies: {
            $0.studyClient.fetchMyStudies = { [] }
        }

        // refresh는 .loading으로 내리지 않고 조용히 재조회
        await store.send(.refresh)
        await store.receive(\.studiesResponse.success) {
            $0.studies = .loaded([])
        }
    }
}
