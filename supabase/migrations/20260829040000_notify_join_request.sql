-- 가입 신청 알림: 스터디 가입 신청(pending)이 생기면 방장에게 알림 생성
--
-- 기존에는 방장이 스터디 상세에 들어가야만 "대기 N명" 배지로 알 수 있었다.
-- notifications INSERT는 기존 웹훅(send-push-notification)을 그대로 타므로 푸시도 함께 나간다.
-- 재신청은 request_join_study RPC가 rejected 행을 DELETE 후 INSERT하므로 INSERT 트리거로 충분.

-- 1. 알림 탭 시 스터디로 이동하기 위한 참조 컬럼 (타 기능들의 reference_* 패턴과 동일)
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS reference_study_id UUID REFERENCES studies(id) ON DELETE CASCADE;

-- 2. 타입 확장
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
        'join_request'
    ));

-- 3. 가입 신청 INSERT → 방장 알림
--    fill_join_request_fields(BEFORE 트리거)가 user_name/study_name을 채운 뒤 실행된다.
CREATE OR REPLACE FUNCTION notify_join_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    IF NEW.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    SELECT owner_id INTO v_owner_id FROM studies WHERE id = NEW.study_id;
    IF v_owner_id IS NULL THEN
        RETURN NEW;
    END IF;

    INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
    VALUES (
        v_owner_id,
        'join_request',
        '새 가입 신청',
        NEW.user_name || '님이 ''' || NEW.study_name || ''' 가입을 신청했습니다.',
        NEW.study_id
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_join_request ON study_join_requests;
CREATE TRIGGER trg_notify_join_request
    AFTER INSERT ON study_join_requests
    FOR EACH ROW EXECUTE FUNCTION notify_join_request();

NOTIFY pgrst, 'reload schema';
