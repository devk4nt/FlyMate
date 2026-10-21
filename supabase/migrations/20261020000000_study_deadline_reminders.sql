-- 주간 마감 리마인더: 방장이 정한 요일 저녁에, 아직 안 한 멤버에게만 알림.
-- "매주 영상 과제랑 피드백 올리는 마감요일이 있는데 스터디원들이 종종 까먹는다"는 요청.
--
-- ponytail: 새 cron job을 만들지 않고 기존 feedback-reminder-daily(20:00 KST)에 올라탄다.
-- 알림 타입도 기존 'feedback_reminder'를 재사용 — 새 rawValue는 배포된 앱이 모르면
-- NotificationType(rawValue:) ?? .feedbackOnMyVideo 로 떨어져 아이콘이 틀어지는데,
-- feedback_reminder의 아이콘(clock.badge.exclamationmark)이 마감 알림에 그대로 맞는다.
-- 앱 릴리스 없이 동작한다. 기존 영상별 리마인드와는 reference_study_id 유무로 구분된다
-- (영상별은 reference_video_id, 마감은 reference_study_id).

-- 0=일 ~ 6=토. Postgres EXTRACT(DOW)와 같은 인코딩이라 비교에 변환이 필요 없다.
ALTER TABLE studies
    ADD COLUMN IF NOT EXISTS video_deadline_weekday    SMALLINT,
    ADD COLUMN IF NOT EXISTS feedback_deadline_weekday SMALLINT;

ALTER TABLE studies DROP CONSTRAINT IF EXISTS studies_video_deadline_weekday_check;
ALTER TABLE studies ADD CONSTRAINT studies_video_deadline_weekday_check
    CHECK (video_deadline_weekday IS NULL OR video_deadline_weekday BETWEEN 0 AND 6);

ALTER TABLE studies DROP CONSTRAINT IF EXISTS studies_feedback_deadline_weekday_check;
ALTER TABLE studies ADD CONSTRAINT studies_feedback_deadline_weekday_check
    CHECK (feedback_deadline_weekday IS NULL OR feedback_deadline_weekday BETWEEN 0 AND 6);

-- 마감 알림 중복 검사가 notifications 전체를 훑지 않도록
CREATE INDEX IF NOT EXISTS idx_notifications_deadline_reminder
    ON notifications (recipient_id, reference_study_id, created_at)
 WHERE type = 'feedback_reminder' AND reference_study_id IS NOT NULL;

CREATE OR REPLACE FUNCTION send_feedback_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    -- cron은 UTC로 돌지만 마감 요일은 한국 기준이어야 한다.
    v_today SMALLINT := EXTRACT(DOW FROM (now() AT TIME ZONE 'Asia/Seoul'))::SMALLINT;
BEGIN
    -- 1) 영상 마감일 — 최근 7일간 이 스터디에 영상을 안 올린 멤버
    INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
    SELECT m.user_id,
           'feedback_reminder',
           '오늘은 영상 마감일이에요',
           s.name || ' · 이번 주 영상을 아직 올리지 않으셨어요.',
           s.id
      FROM studies s
      JOIN study_members m ON m.study_id = s.id
     WHERE s.video_deadline_weekday = v_today
       AND NOT EXISTS (
           SELECT 1 FROM videos v
            WHERE v.study_id = s.id
              AND v.uploader_id = m.user_id
              AND v.created_at >= now() - interval '7 days'
       )
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_study_id = s.id
              AND n.recipient_id = m.user_id
              AND n.created_at > now() - interval '20 hours'
       );

    -- 2) 피드백 마감일 — 최근 7일간 남의 영상에 피드백을 하나도 안 남긴 멤버.
    --    볼 영상이 아예 없으면 보내지 않는다(아무것도 안 올라온 주에 찌르지 않기).
    INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
    SELECT m.user_id,
           'feedback_reminder',
           '오늘은 피드백 마감일이에요',
           s.name || ' · 이번 주 피드백을 아직 남기지 않으셨어요.',
           s.id
      FROM studies s
      JOIN study_members m ON m.study_id = s.id
     WHERE s.feedback_deadline_weekday = v_today
       AND EXISTS (
           SELECT 1 FROM videos v
            WHERE v.study_id = s.id
              AND v.uploader_id <> m.user_id
              AND v.created_at >= now() - interval '7 days'
       )
       AND NOT EXISTS (
           SELECT 1 FROM feedbacks f
            JOIN videos v ON v.id = f.video_id
            WHERE v.study_id = s.id
              AND f.author_id = m.user_id
              AND f.created_at >= now() - interval '7 days'
       )
       -- 영상 마감일과 같은 요일로 잡아둔 스터디는 위에서 이미 한 번 찔렀다.
       -- 저녁에 푸시를 두 번 보내면 알림을 꺼버린다 — 하루 한 번으로 묶는다.
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_study_id = s.id
              AND n.recipient_id = m.user_id
              AND n.created_at > now() - interval '20 hours'
       );

    -- 3) 기존 영상별 피드백 리마인드 (마감일과 무관하게 매일)
    INSERT INTO notifications (recipient_id, type, title, body, reference_video_id)
    SELECT DISTINCT ON (m.user_id)
           m.user_id,
           'feedback_reminder',
           '피드백을 기다리고 있어요',
           v.uploader_name || '님의 "' || LEFT(v.title, 20) || '" 영상, 아직 피드백을 남기지 않으셨어요.',
           v.id
      FROM videos v
      JOIN study_members m
        ON m.study_id = v.study_id
       AND m.user_id <> v.uploader_id
     WHERE v.created_at <  now() - interval '20 hours'
       AND v.created_at >= now() - interval '7 days'
       AND NOT EXISTS (
           SELECT 1 FROM feedbacks f
            WHERE f.video_id = v.id
              AND f.author_id = m.user_id
       )
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_video_id = v.id
              AND n.recipient_id = m.user_id
       )                                                 -- 영상당 1인 1회
       -- 방금 마감 알림을 받은 사람은 건너뛴다 (같은 저녁에 두 번 울리지 않게)
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_study_id = v.study_id
              AND n.recipient_id = m.user_id
              AND n.created_at > now() - interval '20 hours'
       )
     ORDER BY m.user_id, v.created_at DESC;
END;
$$;

NOTIFY pgrst, 'reload schema';
