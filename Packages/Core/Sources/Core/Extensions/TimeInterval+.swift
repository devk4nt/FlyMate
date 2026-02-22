import Foundation

extension TimeInterval {
    /// 초를 "M:SS" 형식으로 변환 (예: 83초 → "1:23")
    public var minuteSecondFormatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 초를 "MM:SS" 형식으로 변환 (예: 83초 → "01:23")
    public var paddedMinuteSecondFormatted: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
