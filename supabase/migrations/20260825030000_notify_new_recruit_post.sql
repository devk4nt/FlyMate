-- 스터디 모집글 작성 시 작성자를 제외한 전 유저에게 알림 fan-out → 기존
-- send-push-notification 웹훅이 자동으로 FCM 푸시 발송.
--
-- ⚠️ 배포 순서 주의: 현재 배포된 앱은 'recruit_post' 타입을 모르며
-- NotificationType(rawValue:) ?? .feedbackOnMyVideo 로 매핑해 오표시된다.
-- 반드시 recruit_post 타입을 처리하는 앱 릴리스가 배포된 뒤에 이 마이그레이션을
-- 적용할 것.

-- 1) 딥링크용 참조 컬럼
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS reference_recruit_post_id UUID
        REFERENCES recruit_posts(id) ON DELETE CASCADE;

-- 2) type check 제약에 recruit_post 추가
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
        'recruit_post'
    ));

-- 3) fan-out 함수: 작성자 및 작성자를 차단한 유저 제외, 숨김 글은 발송 안 함
CREATE OR REPLACE FUNCTION notify_new_recruit_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.is_hidden THEN
        RETURN NEW;
    END IF;

    INSERT INTO notifications (
        recipient_id, type, title, body, reference_recruit_post_id
    )
    SELECT
        u.id,
        'recruit_post',
        '새 스터디 모집글',
        format('%s님이 ''%s'' 모집을 시작했어요', NEW.author_name, NEW.title),
        NEW.id
    FROM users u
    WHERE u.id <> NEW.author_id
      AND NOT EXISTS (
            SELECT 1 FROM blocked_users b
            WHERE b.blocker_id = u.id
              AND b.blocked_id = NEW.author_id);

    RETURN NEW;
END;
$$;

-- 4) 트리거
DROP TRIGGER IF EXISTS trg_notify_new_recruit_post ON recruit_posts;
CREATE TRIGGER trg_notify_new_recruit_post
    AFTER INSERT ON recruit_posts
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_recruit_post();

NOTIFY pgrst, 'reload schema';
