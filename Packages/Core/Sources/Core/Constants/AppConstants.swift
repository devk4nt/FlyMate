import Foundation

public enum AppConstants {
    /// 빠른 피드백 영상의 최대 길이.
    public static let maxQuickFeedbackVideoDurationSeconds: TimeInterval = 60
    /// 빠른 피드백 요청 한 건의 목표 피드백 수.
    public static let quickFeedbackTargetCount = 2
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

    // MARK: - Practice Mirror

    public enum PracticeMirror {
        /// 미소로 판정하는 blendShape(mouthSmileLeft/Right 평균) 최소값
        public static let smileThreshold: Double = 0.3

        /// 미소 샘플 최소 간격 (초) — ARKit 60fps 콜백을 10Hz로 스로틀
        public static let sampleInterval: TimeInterval = 0.1

        /// 리포트가 만들어지는 최소 측정 시간 (초) — 미만이면 리포트 없이 준비 화면으로
        public static let minimumReportDuration: TimeInterval = 10

        /// 앱 평가 요청(requestReview) 최소 누적 리포트 수
        public static let reviewMinCompletedReports = 3

        /// 앱 평가 요청 최소 미소 유지율 — 결과가 좋은 순간에만 요청
        public static let reviewMinSmileRatio: Double = 0.7

        /// 리포트 표시 후 평가 요청까지 지연 (초) — 그래프 볼 여유를 준 다음
        public static let reviewPromptDelay: TimeInterval = 1.5

        /// 1일 1미소 알림 기본 시간 — 자정 기준 분 (09:00)
        public static let reminderDefaultMinutes = 9 * 60

        /// 미소 거울 관련 UserDefaults 키
        public enum UserDefaultsKey {
            /// 유효 리포트 누적 횟수 (Int)
            public static let completedReportCount = "practiceMirror.completedReportCount"
            /// 1일 1미소 알림 사용 여부 (Bool)
            public static let reminderEnabled = "practiceMirror.reminderEnabled"
            /// 알림 시간, 자정 기준 분+1 (Int, 0 = 미설정 — integer 기본값 0과 자정 설정을 구분)
            public static let reminderMinutesPlusOne = "practiceMirror.reminderMinutes"
            /// 최근 미소 유지율 %+1 (Int, 0 = 기록 없음)
            public static let recentSmileRatioPercentPlusOne = "practiceMirror.recentSmileRatioPercent"
        }
    }

    // MARK: - Service URLs

    public enum ServiceURL {
        /// 이용약관 (EULA) — 부적절 콘텐츠 무관용 조항 포함 (App Store Guideline 1.2)
        public static let termsOfService = "https://devk4nt.github.io/flymate-site/terms.html"
        public static let privacyPolicy = "https://devk4nt.github.io/flymate-site/privacy.html"
        /// 초대 링크 랜딩 페이지 — `?code=` 를 붙여 공유하면 페이지가 `flymate://invite` 로 앱을 열고,
        /// 앱이 없으면 App Store 로 안내한다. 카카오톡·문자는 http(s) 링크만 탭 가능하게 렌더링하므로
        /// 커스텀 스킴을 그대로 공유하면 안 된다.
        public static let inviteLanding = "https://devk4nt.github.io/flymate-site/invite.html"
        /// App Store 제품 페이지 (FlyMate - 승무원 면접 스터디) — 짧은 canonical 형태, 슬러그 포함 링크와 동일 페이지
        public static let appStore = "https://apps.apple.com/kr/app/id6801114073"
    }
}
