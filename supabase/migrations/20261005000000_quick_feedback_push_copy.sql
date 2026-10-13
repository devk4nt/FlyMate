-- 빠른 피드백 fan-out 푸시 문구 변경 (20261003000000의 함수만 교체)
--
-- 기존: '{제목}' 영상에 피드백을 남겨주세요
-- 변경: 1분이면 충분해요. '{제목}'에 피드백을 남겨주세요
--
-- "영상 다 봐야 하나" 하는 부담이 탭을 막는 가장 큰 요인이라, 소요 시간을 먼저 보여준다.
-- "1분"은 quick_feedback_requests_duration_seconds_check(duration_seconds <= 60)이
-- 보장하는 상한이라 과장이 아니다. 상한을 늘리면 이 문구도 같이 고칠 것.

CREATE OR REPLACE FUNCTION notify_new_quick_feedback_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.status <> 'open' OR NEW.expires_at <= now() THEN
        RETURN NEW;
    END IF;

    -- 알림 피로도 상한: 수신자 1명당 이 타입은 24시간에 1건까지.
    -- 상한에 걸려 푸시를 못 받아도 공개 풀 목록에는 그대로 보이므로 노출 손실은 없다.
    -- ponytail: 창이 고정 24시간. 시간대/요청 인기도별 조정이 필요해지면 그때 파라미터화.
    INSERT INTO notifications (
        recipient_id, type, title, body, reference_quick_feedback_request_id
    )
    SELECT
        u.id,
        'quick_feedback_request',
        '새 빠른 피드백 요청',
        format('1분이면 충분해요. ''%s''에 피드백을 남겨주세요', NEW.title),
        NEW.id
    FROM users u
    WHERE u.id <> NEW.uploader_id
      AND NOT EXISTS (
            SELECT 1 FROM blocked_users b
            WHERE (b.blocker_id = u.id AND b.blocked_id = NEW.uploader_id)
               OR (b.blocker_id = NEW.uploader_id AND b.blocked_id = u.id))
      AND NOT EXISTS (
            SELECT 1 FROM notifications n
            WHERE n.recipient_id = u.id
              AND n.type = 'quick_feedback_request'
              AND n.created_at > now() - interval '24 hours');

    RETURN NEW;
END;
$$;
