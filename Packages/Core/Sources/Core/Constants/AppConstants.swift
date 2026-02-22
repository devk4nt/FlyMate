import Foundation

public enum AppConstants {
    /// 영상 최대 길이 (초)
    public static let maxVideoDurationSeconds: TimeInterval = 240

    /// 스터디 최대 인원 수
    public static let maxStudyMembers = 8

    /// 페이지네이션 기본 페이지 크기
    public static let defaultPageSize = 20

    /// 피드백 최대 글자 수
    public static let maxFeedbackLength = 500

    /// 스터디 이름 최대 글자 수
    public static let maxStudyNameLength = 30

    /// 초대 코드 길이
    public static let inviteCodeLength = 6

    /// 토스트 표시 시간 (초)
    public static let toastDuration: TimeInterval = 3.0

    /// 디바운스 기본 대기 시간 (초)
    public static let defaultDebounceInterval: TimeInterval = 0.3
}
