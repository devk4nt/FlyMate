-- 빠른 피드백 요청 수명 48시간 → 72시간 (저볼륨 환경에서 피드백 수집 시간 확보)
ALTER TABLE quick_feedback_requests
    ALTER COLUMN expires_at SET DEFAULT (now() + interval '72 hours');

-- 현재 열려 있는 요청에도 새 정책 적용
UPDATE quick_feedback_requests
SET expires_at = created_at + interval '72 hours'
WHERE status = 'open';
