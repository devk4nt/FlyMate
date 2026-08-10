import Foundation

public enum AppConstants {
    /// 사용자 문의를 받는 고객 지원 이메일
    public static let supportEmail = "flymate.team.contact@gmail.com"

    /// 버그 신고 상세 내용 최대 글자 수
    public static let maxBugReportLength = 2_000

    /// 영상 최대 길이 (초) — 피드백 요청 영상은 최대 3분
    public static let maxVideoDurationSeconds: TimeInterval = 180

    /// 영상 최대 파일 크기 (bytes) — Supabase Storage 제한 50MB
    public static let maxVideoFileSizeBytes = 50 * 1_024 * 1_024

    /// 프로필 이미지 최대 변 길이 (px) — 업로드 전 다운스케일 기준
    public static let profileImageMaxDimension: CGFloat = 512

    /// 프로필 이미지 JPEG 압축 품질
    public static let profileImageCompressionQuality: CGFloat = 0.8

    /// 영상 서명 URL 만료 시간 (초) — private 버킷 영상은 만료 전까지만 재생 가능
    public static let signedVideoURLExpirySeconds = 60 * 60

    /// 스터디 최대 인원 수
    public static let maxStudyMembers = 8

    /// 페이지네이션 기본 페이지 크기
    public static let defaultPageSize = 20

    /// 피드백 대기 큐 최대 조회 개수 — 스터디 규모(최대 5개 × 8명)상 페이지네이션 불필요
    public static let pendingFeedbackFetchLimit = 100

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

    // MARK: - Recruit (스터디원 모집)

    /// 모집 글 제목 최대 글자 수
    public static let maxRecruitTitleLength = 50

    /// 모집 글 소개 최대 글자 수
    public static let maxRecruitDescriptionLength = 2_000

    /// 모집 글 최대 모집 인원
    public static let maxRecruitMembers = 20

    /// 모집 글 댓글 최대 글자 수
    public static let maxRecruitCommentLength = 300

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
