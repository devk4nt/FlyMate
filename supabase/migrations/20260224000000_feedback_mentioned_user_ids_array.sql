-- Migration: mentioned_user_id UUID → mentioned_user_ids UUID[]
-- 피드백 멘션을 단일 유저에서 다중 유저(배열)로 변경

-- 1. 기존 컬럼의 데이터를 배열로 마이그레이션한 뒤 컬럼 교체
ALTER TABLE feedbacks
    ADD COLUMN mentioned_user_ids UUID[] NOT NULL DEFAULT '{}';

UPDATE feedbacks
    SET mentioned_user_ids = ARRAY[mentioned_user_id]
    WHERE mentioned_user_id IS NOT NULL;

ALTER TABLE feedbacks
    DROP COLUMN mentioned_user_id;

-- 2. 트리거 함수를 배열 기반으로 교체
CREATE OR REPLACE FUNCTION create_feedback_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_video_owner_id UUID;
    v_video_title TEXT;
    v_author_name TEXT;
    v_mentioned_id UUID;
BEGIN
    -- Lookup video owner and title
    SELECT uploader_id, title INTO v_video_owner_id, v_video_title
    FROM videos WHERE id = NEW.video_id;

    -- Lookup feedback author name
    SELECT name INTO v_author_name
    FROM users WHERE id = NEW.author_id;

    -- Notify video owner (skip if author is the owner)
    IF v_video_owner_id IS NOT NULL AND v_video_owner_id != NEW.author_id THEN
        INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
        VALUES (
            v_video_owner_id,
            'feedback_on_my_video',
            '새 피드백이 달렸어요',
            v_author_name || '님이 "' || LEFT(v_video_title, 20) || '" 영상에 피드백을 남겼습니다.',
            NEW.video_id,
            NEW.id
        );
    END IF;

    -- Notify each mentioned user (skip author)
    IF array_length(NEW.mentioned_user_ids, 1) IS NOT NULL THEN
        FOREACH v_mentioned_id IN ARRAY NEW.mentioned_user_ids
        LOOP
            IF v_mentioned_id != NEW.author_id THEN
                INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
                VALUES (
                    v_mentioned_id,
                    'mentioned_in_feedback',
                    '피드백에서 태그되었어요',
                    v_author_name || '님이 피드백에서 회원님을 태그했습니다.',
                    NEW.video_id,
                    NEW.id
                );
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
