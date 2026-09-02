import XCTest

/// 초대 링크 공유 버튼 → iOS 공유 시트 진입 확인.
/// 목 데이터(기본 FlyMate 스킴)와 스테이징 스킴(FlyMate-Owner 등) 모두에서 동작한다.
final class InviteShareUITests: XCTestCase {

    @MainActor
    func test_스터디_상세에서_초대_링크_공유_시트_진입() throws {
        let app = XCUIApplication()
        app.launch()

        // 첫 실행(fresh 시뮬레이터 = CI)에는 온보딩 → 가이드라인 동의가 화면을 가린다
        let onboardingSkip = app.buttons["건너뛰기"]
        if onboardingSkip.waitForExistence(timeout: 5) {
            onboardingSkip.tap()
        }
        let consentAgree = app.buttons["이용약관에 동의하고 시작하기"]
        if consentAgree.waitForExistence(timeout: 10) {
            consentAgree.tap()
        }
        // 공지 팝업은 시트로 떠서 공유 시트 제시를 막으므로 먼저 닫는다
        let announcementConfirm = app.buttons["확인"]
        if announcementConfirm.waitForExistence(timeout: 5) {
            announcementConfirm.tap()
        }

        let studyTab = app.tabBars.buttons["스터디"]
        XCTAssertTrue(studyTab.waitForExistence(timeout: 20))
        studyTab.tap()

        // 스터디 카드 라벨은 "이름, 멤버 N명, 최대 M명" (StudyListView) — 히어로/빠른피드백 버튼과 구분된다
        let studyCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", ", 멤버 ", "최대 ")
        ).firstMatch
        XCTAssertTrue(studyCard.waitForExistence(timeout: 20), "스터디 카드를 찾지 못함")
        studyCard.tap()

        let shareButton = app.buttons["초대 링크 공유"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10), "초대 링크 공유 버튼을 찾지 못함")
        shareButton.tap()

        // ShareLink는 UIActivityViewController를 띄운다 — 시트가 떴으면 공유 경로가 살아 있는 것
        let activitySheet = app.otherElements["ActivityListView"]
        let copyAction = app.buttons["복사"]
        XCTAssertTrue(
            activitySheet.waitForExistence(timeout: 10) || copyAction.waitForExistence(timeout: 5),
            "공유 시트가 뜨지 않음"
        )
    }
}
