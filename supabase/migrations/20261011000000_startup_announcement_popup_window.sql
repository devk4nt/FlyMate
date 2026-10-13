-- 공지 팝업 백로그 문제 해결:
--   1) 미열람 공지가 쌓이면 앱 진입마다 하나씩 순차로 떠서 사용자를 괴롭혔다 → 진입당 1개만 띄우고 나머지는 팝업 대상에서 제외(알림함에는 그대로 남음)
--   2) 오래된 미열람 공지는 더 이상 팝업하지 않는다 (팝업 유효기간 7일)
CREATE OR REPLACE FUNCTION sync_startup_announcement()
RETURNS SETOF notifications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_user_id UUID := auth.uid();
    popup_window INTERVAL := INTERVAL '7 days';
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

    -- 팝업 유효기간 내 공지 중 가장 최신 1개만 선택
    SELECT notification.id
    INTO selected_notification_id
    FROM notifications AS notification
    JOIN announcements AS announcement
      ON announcement.id = notification.reference_announcement_id
    WHERE notification.recipient_id = current_user_id
      AND notification.popup_shown_at IS NULL
      AND announcement.is_published = true
      AND announcement.starts_at <= now()
      AND announcement.starts_at > now() - popup_window
      AND (announcement.ends_at IS NULL OR announcement.ends_at > now())
    ORDER BY announcement.priority DESC, announcement.starts_at DESC
    LIMIT 1;

    -- 선택된 1개를 포함해 미노출 공지 전체를 노출 처리 → 다음 진입에 줄줄이 뜨지 않는다
    UPDATE notifications
    SET popup_shown_at = now()
    WHERE recipient_id = current_user_id
      AND reference_announcement_id IS NOT NULL
      AND popup_shown_at IS NULL;

    IF selected_notification_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT notification.*
    FROM notifications AS notification
    WHERE notification.id = selected_notification_id;
END;
$$;

COMMENT ON FUNCTION sync_startup_announcement() IS
    '활성 공지를 알림함에 동기화하고, 최근 7일 내 공지 중 아직 팝업하지 않은 1개만 반환한다. 나머지 미노출 공지는 팝업 대상에서 제외한다';
