import Foundation

public enum AppConstants {
    /// 영상 최대 길이 (초) — 피드백 요청 영상은 최대 3분
    public static let maxVideoDurationSeconds: TimeInterval = 180

    /// 영상 최대 파일 크기 (bytes) — Supabase Storage 제한 50MB
    public static let maxVideoFileSizeBytes = 50 * 1_024 * 1_024

    /// 스터디 최대 인원 수
    public static let maxStudyMembers = 8

    /// 페이지네이션 기본 페이지 크기
    public static let defaultPageSize = 20

    /// 피드백 최대 글자 수
    public static let maxFeedbackLength = 500

    /// 피드백 댓글 최대 글자 수
    public static let maxCommentLength = 300

    /// 스터디 이름 최대 글자 수
    public static let maxStudyNameLength = 30

    /// 방장으로 생성 가능한 최대 스터디 수
    public static let maxOwnedStudies = 3

    /// 총 참여 가능한 최대 스터디 수 (방장 + 멤버 합산)
    public static let maxJoinedStudies = 5

    /// 초대 코드 길이
    public static let inviteCodeLength = 6

    /// 토스트 표시 시간 (초)
    public static let toastDuration: TimeInterval = 3.0

    /// 디바운스 기본 대기 시간 (초)
    public static let defaultDebounceInterval: TimeInterval = 0.3

    /// 신고 상세 내용 최대 글자 수
    public static let maxReportDetailLength = 300

    // MARK: - Subscription

    public enum SubscriptionProductID {
        public static let premiumMonthly = "com.flymate.premium.monthly"
        public static let premiumYearly = "com.flymate.premium.yearly"

        public static var all: [String] {
            [premiumMonthly, premiumYearly]
        }
    }

    public enum FreePlanDefaults {
        public static let maxOwnedStudies = 1
        public static let maxJoinedStudies = 1
        public static let maxVideoDurationSeconds = 60
        public static let maxStudyMembers = 3
    }
}
