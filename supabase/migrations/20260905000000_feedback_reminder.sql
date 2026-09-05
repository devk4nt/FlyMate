-- 영상이 올라왔는데 피드백이 하루가 지나도 0건이면 스터디 멤버에게 리마인드
-- 새 영상 알림(new_video_in_study)을 놓쳤거나 미룬 사람을 다시 부르는 용도.
--
-- 하루 한 번 20:00 KST 에만 돈다. 매시간 돌리면 새벽에 푸시가 나가고,
-- 이 앱의 활동은 대부분 저녁~자정 사이에 몰려 있다.

CREATE EXTENSION IF NOT EXISTS pg_cron;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY[
    'feedback_on_my_video', 'mentioned_in_feedback', 'reply_on_my_feedback',
    'mentioned_in_feedback_comment', 'announcement', 'quick_feedback_received',
    'recruit_post', 'join_request', 'join_request_approved', 'join_request_rejected',
    'new_video_in_study', 'feedback_reminder'
]));

CREATE OR REPLACE FUNCTION send_feedback_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- DISTINCT ON: 한 사람이 여러 영상의 리마인드를 한꺼번에 받지 않도록
    -- 가장 최근 영상 하나만 고른다. 나머지는 다음 날 차례가 온다.
    INSERT INTO notifications (recipient_id, type, title, body, reference_video_id)
    SELECT DISTINCT ON (m.user_id)
           m.user_id,
           'feedback_reminder',
           '피드백을 기다리고 있어요',
           v.uploader_name || '님의 "' || LEFT(v.title, 20) || '" 영상에 아직 피드백이 없어요.',
           v.id
      FROM videos v
      JOIN study_members m
        ON m.study_id = v.study_id
       AND m.user_id <> v.uploader_id
     WHERE v.created_at <  now() - interval '20 hours'   -- 하루는 기다려 준다
       AND v.created_at >= now() - interval '7 days'     -- 오래된 영상까지 파헤치지 않는다
       AND NOT EXISTS (SELECT 1 FROM feedbacks f WHERE f.video_id = v.id)
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_video_id = v.id
              AND n.recipient_id = m.user_id
       )                                                 -- 영상당 1인 1회
     ORDER BY m.user_id, v.created_at DESC;
END;
$$;

SELECT cron.unschedule('feedback-reminder-daily')
 WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'feedback-reminder-daily');

SELECT cron.schedule(
    'feedback-reminder-daily',
    '0 11 * * *',                                        -- 11:00 UTC = 20:00 KST
    $job$SELECT send_feedback_reminders()$job$
);
