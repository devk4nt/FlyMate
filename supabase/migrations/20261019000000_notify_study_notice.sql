-- 방장이 스터디 공지를 등록/수정하면 멤버 전원에게 알림 + 푸시.
-- notifications INSERT → send-push-on-notification-insert 웹훅이 FCM까지 처리한다.
--
-- ponytail: 새 type을 만들지 않고 기존 'announcement'를 재사용한다.
--   새 rawValue는 이미 배포된 앱이 모르므로(NotificationType(rawValue:) ?? .feedbackOnMyVideo)
--   아이콘이 오표시되고 앱 릴리스를 기다려야 한다. 'announcement'는 아이콘(bell.badge.fill)과
--   탭 동작(AnnouncementDetailView 시트에 title/body/시각 렌더링)이 공지에 그대로 맞아서
--   앱 코드 변경 0줄로 v1.13 설치 기기에서 즉시 동작한다.
--   개발자 전체 공지와는 reference_study_id 유무로 구분된다(전체 공지는 NULL).
--   알림 목록에서 둘을 다르게 보여줄 필요가 생기면 그때 study_notice 타입으로 쪼갠다.

-- 디바운스 조회가 notifications 전체를 훑지 않도록 (공지 중복 방지 인덱스와 같은 형태)
CREATE INDEX IF NOT EXISTS idx_notifications_study_notice
    ON notifications (reference_study_id, created_at)
 WHERE type = 'announcement' AND reference_study_id IS NOT NULL;

CREATE OR REPLACE FUNCTION notify_study_notice()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- UPDATE OF notice는 값이 그대로여도 발화하므로 실제 변경만 통과시킨다.
    IF NEW.notice IS NOT DISTINCT FROM OLD.notice THEN
        RETURN NEW;
    END IF;

    -- 공지 삭제(NULL/공백)는 알리지 않는다.
    IF NEW.notice IS NULL OR btrim(NEW.notice) = '' THEN
        RETURN NEW;
    END IF;

    -- ponytail: 10분 디바운스. 방장이 오타를 고칠 때마다 멤버 전원에게 푸시가 나가는 걸 막는다.
    -- 천장: 10분 안에 올린 '진짜 두 번째 공지'는 묻힌다. 공지를 자주 쪼개 올리는 패턴이
    -- 관측되면 notice 해시를 따로 기록해 '같은 내용 재발송만' 막는 방식으로 올린다.
    IF EXISTS (
        SELECT 1 FROM notifications
         WHERE type = 'announcement'
           AND reference_study_id = NEW.id
           AND created_at > now() - interval '10 minutes'
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO notifications (
        recipient_id, type, title, body, reference_study_id
    )
    SELECT
        m.user_id,
        'announcement',
        NEW.name || ' 공지',
        NEW.notice,
        NEW.id
    FROM study_members m
    WHERE m.study_id = NEW.id
      AND m.user_id <> NEW.owner_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_study_notice ON studies;
CREATE TRIGGER trg_notify_study_notice
    AFTER UPDATE OF notice ON studies
    FOR EACH ROW
    EXECUTE FUNCTION notify_study_notice();

NOTIFY pgrst, 'reload schema';
