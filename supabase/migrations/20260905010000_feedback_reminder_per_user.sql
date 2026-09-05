-- 리마인드 대상을 영상 단위 → 유저 단위로 전환
--
-- 기존: 영상에 피드백이 하나라도 있으면 아무에게도 안 보냈다.
--   5명 스터디에서 한 명만 답해도 나머지 3명이 풀려나는 구조라,
--   "여러 명이 본다"는 스터디 피드백의 핵심 가치와 어긋난다.
-- 변경: 그 영상에 아직 피드백을 남기지 않은 사람에게만 보낸다.
--
-- 1인 1영상 1회 규칙은 그대로 둔다(notifications 중복 검사). 응답할 때까지
-- 반복해서 찌르지 않는다.
--
-- 문구도 함께 바꾼다: 유저 단위가 되면 남이 이미 남긴 영상에도 알림이 가므로
-- "아직 피드백이 없어요"는 사실과 다를 수 있다.

CREATE OR REPLACE FUNCTION send_feedback_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
       )                                                 -- 내가 아직 안 남긴 영상
       AND NOT EXISTS (
           SELECT 1 FROM notifications n
            WHERE n.type = 'feedback_reminder'
              AND n.reference_video_id = v.id
              AND n.recipient_id = m.user_id
       )                                                 -- 영상당 1인 1회
     ORDER BY m.user_id, v.created_at DESC;
END;
$$;
