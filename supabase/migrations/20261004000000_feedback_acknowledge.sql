-- 피드백 체크: 영상 주인이 받은 피드백에 "확인했어요" 표시를 하고,
-- 피드백 작성자에게 알림이 간다. 답글 하나하나 쓰는 부담 없이 고마움을 전하는 용도.
--
-- RLS 정책을 넓히지 않고 SECURITY DEFINER 함수로 처리한다:
-- feedbacks FOR UPDATE 를 영상 주인까지 열면 RLS는 컬럼 단위 제한을 못 해서
-- 남의 피드백 본문까지 고칠 수 있게 된다.

ALTER TABLE feedbacks ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ;

-- type check 제약에 feedback_acknowledged 추가 (빠뜨리면 함수가 INSERT에서 터진다)
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
        'quick_feedback_request',
        'recruit_post',
        'join_request',
        'join_request_approved',
        'join_request_rejected',
        'new_video_in_study',
        'feedback_reminder',
        'feedback_acknowledged'
    ));

-- 위 NOT EXISTS 가 매 탭마다 notifications 전체를 훑지 않도록 (공지 중복 방지 인덱스와 같은 형태)
CREATE INDEX IF NOT EXISTS idx_notifications_ack_feedback
    ON notifications (reference_feedback_id)
 WHERE type = 'feedback_acknowledged';

CREATE OR REPLACE FUNCTION acknowledge_feedback(
    p_feedback_id UUID,
    p_acknowledged BOOLEAN
)
RETURNS SETOF feedbacks
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller UUID := auth.uid();
    v_uploader_id UUID;
    v_video_id UUID;
    v_author_id UUID;
    v_uploader_name TEXT;
BEGIN
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT v.uploader_id, v.id, f.author_id
      INTO v_uploader_id, v_video_id, v_author_id
      FROM feedbacks f
      JOIN videos v ON v.id = f.video_id
     WHERE f.id = p_feedback_id;

    IF v_video_id IS NULL THEN
        RAISE EXCEPTION 'Feedback not found';
    END IF;

    -- 영상 주인만 체크할 수 있다 (자기 피드백에는 의미가 없으므로 그대로 허용만 함)
    IF v_uploader_id <> v_caller THEN
        RAISE EXCEPTION 'Only the video owner can acknowledge feedback';
    END IF;

    UPDATE feedbacks
       SET acknowledged_at = CASE WHEN p_acknowledged THEN now() ELSE NULL END
     WHERE id = p_feedback_id;

    -- 켤 때만, 그리고 이 피드백으로 알림을 보낸 적이 없을 때만 (피드백당 1회).
    -- acknowledged_at은 끄면 null로 돌아가므로 '이전 상태'로는 재발송을 막지 못한다 —
    -- 끄고 다시 켜는 토글 반복에 작성자가 같은 푸시를 계속 받게 된다.
    IF p_acknowledged AND v_author_id <> v_caller AND NOT EXISTS (
        SELECT 1 FROM notifications
         WHERE type = 'feedback_acknowledged'
           AND reference_feedback_id = p_feedback_id
    ) THEN
        SELECT name INTO v_uploader_name FROM users WHERE id = v_caller;

        INSERT INTO notifications (
            recipient_id, type, title, body,
            reference_video_id, reference_feedback_id
        )
        VALUES (
            v_author_id,
            'feedback_acknowledged',
            '피드백을 확인했어요',
            COALESCE(v_uploader_name, '멤버') || '님이 내 피드백을 확인했어요.',
            v_video_id,
            p_feedback_id
        );
    END IF;

    RETURN QUERY SELECT * FROM feedbacks WHERE id = p_feedback_id;
END;
$$;

REVOKE ALL ON FUNCTION acknowledge_feedback(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION acknowledge_feedback(UUID, BOOLEAN) TO authenticated;

-- 확인 표시가 다른 멤버 화면에도 바로 반영되려면 feedbacks UPDATE가
-- realtime publication을 타야 한다 (observeFeedbacks는 AnyAction = 전체 변경 구독).
-- 대시보드에서 이미 켜 뒀을 수 있어 멱등 처리.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
         WHERE pubname = 'supabase_realtime' AND tablename = 'feedbacks'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE feedbacks;
    END IF;
END $$;
