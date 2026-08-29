-- 가입 신청 결과 알림: 방장이 승인/거절하면 신청자에게 알림 생성 (20260829040000의 후속)
--
-- approve_join_request / reject_join_request RPC 모두 status를 UPDATE하므로 UPDATE 트리거로 잡는다.
-- 승인은 스터디로 이동할 수 있게 reference_study_id를 싣고,
-- 거절은 스터디 접근 권한이 없으므로 참조 없이 본문만 전달한다(탭 시 무동작).

-- 1. 타입 확장
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'feedback_on_my_video',
        'mentioned_in_feedback',
        'reply_on_my_feedback',
        'mentioned_in_feedback_comment',
        'announcement',
        'quick_feedback_received',
        'recruit_post',
        'join_request',
        'join_request_approved',
        'join_request_rejected'
    ));

-- 2. 승인/거절 → 신청자 알림
CREATE OR REPLACE FUNCTION notify_join_request_result()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.status <> 'pending' OR NEW.status NOT IN ('approved', 'rejected') THEN
        RETURN NEW;
    END IF;

    IF NEW.status = 'approved' THEN
        INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
        VALUES (
            NEW.user_id,
            'join_request_approved',
            '가입 승인',
            '''' || NEW.study_name || ''' 가입이 승인되었습니다. 환영합니다!',
            NEW.study_id
        );
    ELSE
        INSERT INTO notifications (recipient_id, type, title, body)
        VALUES (
            NEW.user_id,
            'join_request_rejected',
            '가입 신청 결과',
            '''' || NEW.study_name || ''' 가입 신청이 거절되었습니다.'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_join_request_result ON study_join_requests;
CREATE TRIGGER trg_notify_join_request_result
    AFTER UPDATE ON study_join_requests
    FOR EACH ROW EXECUTE FUNCTION notify_join_request_result();

NOTIFY pgrst, 'reload schema';
