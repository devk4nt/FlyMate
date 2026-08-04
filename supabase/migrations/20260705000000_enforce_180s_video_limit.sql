-- ============================================================
-- 영상 길이 정책 통일: 피드백 요청 영상 최대 3분(180초)
-- 클라이언트(AppConstants) 검증과 함께 서버에서도 강제한다.
-- ============================================================

-- 프리미엄 플랜의 600초 제한을 전역 정책 180초로 축소
UPDATE subscription_plans
SET max_video_duration_seconds = 180
WHERE max_video_duration_seconds > 180;

-- 신규 업로드부터 180초 초과 방지
-- NOT VALID: 정책 변경 이전에 업로드된 기존 영상은 보존
ALTER TABLE videos
    ADD CONSTRAINT videos_duration_seconds_max_180
    CHECK (duration_seconds <= 180) NOT VALID;
