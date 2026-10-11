-- 빠른 피드백 요청 업로드 시 업로더를 제외한 전 유저에게 알림 fan-out →
-- 기존 send-push-notification 웹훅이 자동으로 FCM 푸시 발송.
--
-- 공개 풀(20260930000000)로 전환했지만 유입 경로가 "스터디 탭에 직접 들어와
-- 목록을 봐야 함"뿐이어서 리뷰 제출이 붙지 않았다. 모집글(notify_new_recruit_post)과
-- 같은 fan-out 패턴을 적용한다.
--
-- ⚠️ 배포 순서: 현재 배포된 앱은 'quick_feedback_request' 타입을 모르고
-- NotificationType(rawValue:) ?? .feedbackOnMyVideo 로 매핑해 아이콘이 오표시된다
-- (탭 이동은 reference_quick_feedback_request_id 기반이라 정상). 반드시 이 타입을
-- 처리하는 앱 릴리스가 배포된 뒤에 적용할 것.

-- 1) type check 제약에 quick_feedback_request 추가
ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'feedback_on_my_video',
        'mentioned_in_feedback',
        'reply_on_my_feedback',
        'mentioned_in_feedback_comment',
        'announcement',
        'quick_feedback_received',
        'quick_feedback_request',
        'recruit_post',
        'join_request',
        'join_request_approved',
        'join_request_rejected',
        'new_video_in_study',
        'feedback_reminder'
    ));

-- 2) fan-out 함수: 업로더 및 차단 관계(양방향) 제외
--    차단 양방향 제외는 list_available_quick_feedback_requests 의 노출 조건과 동일하게 맞춘 것
--    (목록에서 볼 수 없는 요청의 알림을 보내지 않는다)
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
        format('''%s'' 영상에 피드백을 남겨주세요', NEW.title),
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

-- 3) 트리거: uploader_name 비정규화(BEFORE INSERT) 이후에 돌도록 AFTER INSERT
DROP TRIGGER IF EXISTS notify_new_quick_feedback_request_trigger
    ON quick_feedback_requests;

CREATE TRIGGER notify_new_quick_feedback_request_trigger
    AFTER INSERT ON quick_feedback_requests
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_quick_feedback_request();
