import Foundation
import ComposableArchitecture
import UserNotifications
import Core

/// 1일 1미소 로컬 알림 — 서버 없이 UNUserNotificationCenter 예약으로 동작한다.
public struct SmileReminderClient: Sendable {
    /// 앞으로 7일치 알림을 재예약한다. 첫 알림은 최근 유지율(%)이 있으면 개인화 문구.
    public var reschedule: @Sendable (_ minutesFromMidnight: Int, _ recentSmileRatioPercent: Int?) async -> Void
    public var cancelAll: @Sendable () async -> Void

    public init(
        reschedule: @escaping @Sendable (Int, Int?) async -> Void,
        cancelAll: @escaping @Sendable () async -> Void
    ) {
        self.reschedule = reschedule
        self.cancelAll = cancelAll
    }
}

extension SmileReminderClient: DependencyKey {
    private static let identifiers = (0..<7).map { "smile-reminder-\($0)" }

    public static let liveValue = SmileReminderClient(
        reschedule: { minutes, recentPercent in
            // ponytail: 7일 롤링 일회성 예약 — 설정 변경·리포트 생성 시 갱신되므로,
            // 앱을 7일간 열지 않으면 알림이 멈춘다 (의도된 안티스팸). 상시 반복이 필요해지면 repeats 트리거로 교체.
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)

            let calendar = Calendar.current
            let now = Date()
            var isFirstScheduled = true
            for (index, identifier) in identifiers.enumerated() {
                guard let day = calendar.date(byAdding: .day, value: index, to: now) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = minutes / 60
                components.minute = minutes % 60
                guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "오늘의 미소 연습 시간이에요 😊"
                if isFirstScheduled, let percent = recentPercent {
                    content.body = "최근 미소 유지율 \(percent)%였어요. 오늘도 이어가볼까요?"
                } else {
                    content.body = "거울 보며 1분, 오늘의 미소를 만들어보세요 ✈️"
                }
                content.sound = .default
                isFirstScheduled = false

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
                try? await center.add(
                    UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                )
            }
        },
        cancelAll: {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    )

    public static let testValue = SmileReminderClient(
        reschedule: unimplemented("\(Self.self).reschedule"),
        cancelAll: unimplemented("\(Self.self).cancelAll")
    )
}

extension DependencyValues {
    public var smileReminderClient: SmileReminderClient {
        get { self[SmileReminderClient.self] }
        set { self[SmileReminderClient.self] = newValue }
    }
}
