-- 스터디에 새 영상이 올라오면 업로더를 제외한 멤버 전원에게 알림
-- notifications INSERT → send-push-on-notification-insert 웹훅이 푸시까지 처리한다.
-- reference_study_id는 일부러 비워 둔다: NotificationListFeature.navigationEffect가
-- study_id를 video_id보다 먼저 보기 때문에, 채우면 영상 대신 스터디 목록으로 빠진다.

-- type CHECK 제약에 새 타입 추가 (빠뜨리면 트리거가 INSERT에서 터진다)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY[
    'feedback_on_my_video', 'mentioned_in_feedback', 'reply_on_my_feedback',
    'mentioned_in_feedback_comment', 'announcement', 'quick_feedback_received',
    'recruit_post', 'join_request', 'join_request_approved', 'join_request_rejected',
    'new_video_in_study'
]));

CREATE OR REPLACE FUNCTION create_video_upload_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_uploader_name TEXT;
    v_member_id UUID;
BEGIN
    SELECT name INTO v_uploader_name FROM users WHERE id = NEW.uploader_id;
    v_uploader_name := COALESCE(v_uploader_name, NEW.uploader_name, '멤버');

    FOR v_member_id IN
        SELECT user_id FROM study_members
        WHERE study_id = NEW.study_id AND user_id != NEW.uploader_id
    LOOP
        INSERT INTO notifications (recipient_id, type, title, body, reference_video_id)
        VALUES (
            v_member_id,
            'new_video_in_study',
            '새 영상이 올라왔어요',
            v_uploader_name || '님이 "' || LEFT(NEW.title, 20) || '" 영상을 올렸어요. 피드백을 남겨주세요.',
            NEW.id
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_new_study_video ON videos;
CREATE TRIGGER trg_notify_new_study_video
    AFTER INSERT ON videos
    FOR EACH ROW
    EXECUTE FUNCTION create_video_upload_notification();
