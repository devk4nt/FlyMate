-- 운영 공지 원본. 실제 사용자 알림은 앱 시작 시 notifications에 한 번만 동기화한다.
CREATE TABLE announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL CHECK (char_length(trim(title)) BETWEEN 1 AND 100),
    body TEXT NOT NULL CHECK (char_length(trim(body)) BETWEEN 1 AND 5000),
    priority SMALLINT NOT NULL DEFAULT 0,
    starts_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at TIMESTAMPTZ,
    is_published BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX idx_announcements_active
    ON announcements(is_published, starts_at DESC, priority DESC);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read published announcements"
    ON announcements FOR SELECT TO authenticated
    USING (is_published = true);

ALTER TABLE notifications
    ADD COLUMN reference_announcement_id UUID REFERENCES announcements(id) ON DELETE SET NULL,
    ADD COLUMN popup_shown_at TIMESTAMPTZ;

CREATE UNIQUE INDEX idx_notifications_recipient_announcement
    ON notifications(recipient_id, reference_announcement_id)
    WHERE reference_announcement_id IS NOT NULL;

ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'feedback_on_my_video',
        'mentioned_in_feedback',
        'reply_on_my_feedback',
        'mentioned_in_feedback_comment',
        'announcement'
    ));

CREATE OR REPLACE FUNCTION sync_startup_announcement()
RETURNS SETOF notifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    selected_notification_id UUID;
BEGIN
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    INSERT INTO notifications (
        recipient_id,
        type,
        title,
        body,
        reference_announcement_id
    )
    SELECT
        current_user_id,
        'announcement',
        announcement.title,
        announcement.body,
        announcement.id
    FROM announcements AS announcement
    WHERE announcement.is_published = true
      AND announcement.starts_at <= now()
      AND (announcement.ends_at IS NULL OR announcement.ends_at > now())
    ON CONFLICT (recipient_id, reference_announcement_id)
        WHERE reference_announcement_id IS NOT NULL
        DO NOTHING;

    SELECT notification.id
    INTO selected_notification_id
    FROM notifications AS notification
    JOIN announcements AS announcement
      ON announcement.id = notification.reference_announcement_id
    WHERE notification.recipient_id = current_user_id
      AND notification.popup_shown_at IS NULL
      AND announcement.is_published = true
      AND announcement.starts_at <= now()
      AND (announcement.ends_at IS NULL OR announcement.ends_at > now())
    ORDER BY announcement.priority DESC, announcement.starts_at DESC
    LIMIT 1
    FOR UPDATE OF notification SKIP LOCKED;

    IF selected_notification_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE notifications
    SET popup_shown_at = now()
    WHERE id = selected_notification_id;

    RETURN QUERY
    SELECT notification.*
    FROM notifications AS notification
    WHERE notification.id = selected_notification_id;
END;
$$;

REVOKE ALL ON FUNCTION sync_startup_announcement() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION sync_startup_announcement() TO authenticated;

COMMENT ON TABLE announcements IS
    'Supabase Dashboard 또는 service role에서 등록하는 앱 운영 공지';
COMMENT ON FUNCTION sync_startup_announcement() IS
    '활성 공지를 현재 사용자의 알림함에 동기화하고 아직 팝업으로 노출하지 않은 공지 하나를 반환한다';
