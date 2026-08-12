import Foundation
import Testing
import Core

struct DateFormattingTests {
    @Test
    func 축약_날짜를_한국어_형식으로_표시한다() throws {
        let timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 12))
        )

        #expect(date.koreanAbbreviated == "2026년 8월 12일")
    }
}
