import Foundation

extension Date {
    /// 상대 시간 문자열 (예: "방금 전", "3분 전", "2시간 전", "3일 전")
    public var relativeString: String {
        let interval = Date.now.timeIntervalSince(self)

        switch interval {
        case ..<60:
            return "방금 전"
        case 60..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)분 전"
        case 3600..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)시간 전"
        case 86400..<604_800:
            let days = Int(interval / 86400)
            return "\(days)일 전"
        default:
            return formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// "yyyy.MM.dd" 포맷 문자열
    public var dotFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self)
    }

    /// "M월 d일 (E)" 포맷 문자열
    public var koreanFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: self)
    }
}
