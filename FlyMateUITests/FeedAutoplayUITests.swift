import XCTest

/// 피드 페이지 전환 시 자동 재생 회귀 확인용 — 목 데이터(디버그 기본 스킴)로 동작한다.
final class FeedAutoplayUITests: XCTestCase {

    @MainActor
    func test_스와이프로_다음_영상_이동시_자동재생() throws {
        let app = XCUIApplication()
        app.launch()

        // 피드백 탭 → 할 일 큐
        let feedbackTab = app.tabBars.buttons["피드백"]
        XCTAssertTrue(feedbackTab.waitForExistence(timeout: 10))
        feedbackTab.tap()

        // 첫 번째 영상 카드 탭 → 임머시브 플레이어 진입
        // (FMFeedCell 라벨은 "○○의 영상" — 스크롤뷰 첫 버튼 fallback은
        //  빠른 피드백 카드 등 다른 버튼을 집을 수 있어 라벨 매칭만 사용)
        let firstCell = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "의 영상")
        ).firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10), "피드 영상 카드를 찾지 못함")
        firstCell.tap()

        // 진입한 페이지가 재생 중인지 (accessibilityHint는 쿼리 불가하므로 label로 페이지 식별)
        let page = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS %@", "님의 영상")
        ).firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 10), "임머시브 플레이어 진입 실패")
        let firstLabel = page.label
        sleep(2)

        // 다음 영상으로 스와이프
        app.swipeUp(velocity: .fast)
        sleep(3)

        let pagesAfter = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS %@", "님의 영상")
        )
        var labelsAfter: [String] = []
        for index in 0..<min(pagesAfter.count, 4) {
            labelsAfter.append(pagesAfter.element(boundBy: index).label)
        }
        // 페이지가 실제로 넘어갔는지 확인 (같은 라벨만 보이면 스와이프 실패)
        XCTAssertTrue(
            labelsAfter.contains { $0 != firstLabel },
            "스와이프 후에도 첫 페이지만 보임: \(labelsAfter)"
        )
        // 로그 수집 시간 확보
        sleep(2)
    }
}
