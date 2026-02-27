-- Migration: feedback_comments 테이블 생성
-- 피드백에 대한 댓글 기능 추가

-- ============================================================
-- 1. feedback_comments 테이블 생성
-- ============================================================

CREATE TABLE feedback_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feedback_id UUID NOT NULL REFERENCES feedbacks(id) ON DELETE CASCADE,
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    author_id UUID NOT NULL,  -- FK 없음 (탈퇴 시 보존)
    author_name TEXT NOT NULL DEFAULT '',
    author_profile_url TEXT,
    content TEXT NOT NULL,
    mentioned_user_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. Indexes
-- ============================================================

CREATE INDEX idx_feedback_comments_feedback_id ON feedback_comments(feedback_id, created_at);
CREATE INDEX idx_feedback_comments_author_id ON feedback_comments(author_id);

-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE feedback_comments ENABLE ROW LEVEL SECURITY;

-- 스터디 멤버만 조회 가능
CREATE POLICY "Study members can read feedback comments"
    ON feedback_comments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = feedback_comments.study_id
              AND study_members.user_id = auth.uid()
        )
    );

-- 스터디 멤버만 작성 가능
CREATE POLICY "Study members can create feedback comments"
    ON feedback_comments FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = feedback_comments.study_id
              AND study_members.user_id = auth.uid()
        )
    );

-- 본인 작성 댓글만 삭제 가능
CREATE POLICY "Authors can delete own feedback comments"
    ON feedback_comments FOR DELETE
    USING (auth.uid() = author_id);

-- ============================================================
-- 4. feedbacks 테이블에 comment_count 추가
-- ============================================================

ALTER TABLE feedbacks ADD COLUMN comment_count INT NOT NULL DEFAULT 0;

-- ============================================================
-- 5. Trigger: comment_count 자동 증감
-- ============================================================

CREATE OR REPLACE FUNCTION update_feedback_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE feedbacks
        SET comment_count = comment_count + 1
        WHERE id = NEW.feedback_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE feedbacks
        SET comment_count = comment_count - 1
        WHERE id = OLD.feedback_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_feedback_comment_count
    AFTER INSERT OR DELETE ON feedback_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_feedback_comment_count();

-- ============================================================
-- 6. notifications CHECK constraint 업데이트
-- ============================================================

ALTER TABLE notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'feedback_on_my_video',
        'mentioned_in_feedback',
        'reply_on_my_feedback',
        'mentioned_in_feedback_comment'
    ));

-- ============================================================
-- 7. Trigger: 댓글 알림 생성
-- ============================================================

CREATE OR REPLACE FUNCTION create_feedback_comment_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_feedback_author_id UUID;
    v_video_id UUID;
    v_author_name TEXT;
    v_mentioned_id UUID;
BEGIN
    -- 피드백 작성자 및 video_id 조회
    SELECT author_id, video_id INTO v_feedback_author_id, v_video_id
    FROM feedbacks WHERE id = NEW.feedback_id;

    -- 댓글 작성자 이름 조회
    SELECT name INTO v_author_name
    FROM users WHERE id = NEW.author_id;

    -- 피드백 작성자에게 알림 (본인 제외)
    IF v_feedback_author_id IS NOT NULL AND v_feedback_author_id != NEW.author_id THEN
        INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
        VALUES (
            v_feedback_author_id,
            'reply_on_my_feedback',
            '피드백에 댓글이 달렸어요',
            v_author_name || '님이 회원님의 피드백에 댓글을 남겼습니다.',
            v_video_id,
            NEW.feedback_id
        );
    END IF;

    -- 멘션된 유저에게 알림 (본인 제외)
    IF array_length(NEW.mentioned_user_ids, 1) IS NOT NULL THEN
        FOREACH v_mentioned_id IN ARRAY NEW.mentioned_user_ids
        LOOP
            IF v_mentioned_id != NEW.author_id THEN
                INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
                VALUES (
                    v_mentioned_id,
                    'mentioned_in_feedback_comment',
                    '댓글에서 태그되었어요',
                    v_author_name || '님이 댓글에서 회원님을 태그했습니다.',
                    v_video_id,
                    NEW.feedback_id
                );
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_feedback_comment_notification
    AFTER INSERT ON feedback_comments
    FOR EACH ROW
    EXECUTE FUNCTION create_feedback_comment_notification();

-- ============================================================
-- 8. RPC: fetch_latest_feedback_comments
--    각 feedback_id별 최신 댓글 1개를 반환
-- ============================================================

CREATE OR REPLACE FUNCTION fetch_latest_feedback_comments(p_feedback_ids UUID[])
RETURNS SETOF feedback_comments
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT ON (feedback_id) *
    FROM feedback_comments
    WHERE feedback_id = ANY(p_feedback_ids)
    ORDER BY feedback_id, created_at DESC;
$$;

-- ============================================================
-- 9. 익명화 RPC 업데이트
-- ============================================================

-- anonymize_member_in_study: feedback_comments도 익명화
CREATE OR REPLACE FUNCTION anonymize_member_in_study(
    p_study_id UUID,
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- Only the user themselves or the study owner may call this
    IF v_caller_id != p_user_id
       AND NOT EXISTS (
           SELECT 1 FROM studies
           WHERE id = p_study_id AND owner_id = v_caller_id
       )
    THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- Anonymize videos in this study
    UPDATE videos
    SET uploader_name = '탈퇴한 멤버'
    WHERE study_id = p_study_id
      AND uploader_id = p_user_id;

    -- Anonymize feedbacks in this study
    UPDATE feedbacks
    SET author_name = '탈퇴한 멤버',
        author_profile_url = NULL
    WHERE study_id = p_study_id
      AND author_id = p_user_id;

    -- Remove departed user from mentioned_user_ids in feedbacks
    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE study_id = p_study_id
      AND p_user_id = ANY(mentioned_user_ids);

    -- Anonymize feedback_comments in this study
    UPDATE feedback_comments
    SET author_name = '탈퇴한 멤버',
        author_profile_url = NULL
    WHERE study_id = p_study_id
      AND author_id = p_user_id;

    -- Remove departed user from mentioned_user_ids in feedback_comments
    UPDATE feedback_comments
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE study_id = p_study_id
      AND p_user_id = ANY(mentioned_user_ids);
END;
$$;

-- anonymize_user_all_studies: feedback_comments도 익명화
CREATE OR REPLACE FUNCTION anonymize_user_all_studies(
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Anonymize all videos by this user
    UPDATE videos
    SET uploader_name = '탈퇴한 멤버'
    WHERE uploader_id = p_user_id;

    -- Anonymize all feedbacks by this user
    UPDATE feedbacks
    SET author_name = '탈퇴한 멤버',
        author_profile_url = NULL
    WHERE author_id = p_user_id;

    -- Remove user from all mentioned_user_ids arrays in feedbacks
    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids);

    -- Anonymize all feedback_comments by this user
    UPDATE feedback_comments
    SET author_name = '탈퇴한 멤버',
        author_profile_url = NULL
    WHERE author_id = p_user_id;

    -- Remove user from all mentioned_user_ids arrays in feedback_comments
    UPDATE feedback_comments
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids);
END;
$$;

-- ============================================================
-- 10. PostgREST 스키마 캐시 리로드
-- ============================================================

NOTIFY pgrst, 'reload schema';
