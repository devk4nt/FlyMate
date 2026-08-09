-- ============================================================
-- Migration: Delete departed member content
--
-- Policy change (replaces 20260225000000 anonymize policy):
-- When a member leaves a study, is removed, or deletes their
-- account, their content is now DELETED, not anonymized:
--   - videos (rows + storage cleanup by caller) — feedbacks/comments
--     on those videos cascade
--   - feedbacks / feedback_comments they authored
-- Mentions of the departed user in SURVIVING content are rewritten
-- to '@탈퇴한사용자' and removed from mentioned_user_ids.
-- ============================================================

DROP FUNCTION IF EXISTS anonymize_member_in_study(UUID, UUID);
DROP FUNCTION IF EXISTS anonymize_user_all_studies(UUID);

-- ------------------------------------------------------------
-- 1. Helper: rewrite '@{name}' → '@탈퇴한사용자' in surviving
--    feedbacks / feedback_comments. p_study_id NULL = all studies.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rewrite_departed_mentions(
    p_user_id UUID,
    p_name TEXT,
    p_study_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pattern TEXT;
BEGIN
    -- Escape regex metacharacters in the name; a mention token ends
    -- at whitespace or end-of-text (matches client-side @\S+ parsing).
    v_pattern := '@' || regexp_replace(p_name, '([\\^$.|?*+()\[\]{}])', '\\\1', 'g') || '(?=\s|$)';

    UPDATE feedbacks
    SET content = regexp_replace(content, v_pattern, '@탈퇴한사용자', 'g'),
        mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids)
      AND (p_study_id IS NULL OR study_id = p_study_id);

    UPDATE feedback_comments
    SET content = regexp_replace(content, v_pattern, '@탈퇴한사용자', 'g'),
        mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids)
      AND (p_study_id IS NULL OR study_id = p_study_id);
END;
$$;

-- ------------------------------------------------------------
-- 2. RPC: remove_member_content_in_study
--    Called on study leave / member removal.
--    Returns deleted video IDs so the caller can remove the
--    corresponding storage files ({study_id}/{video_id}.mp4/.jpg).
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION remove_member_content_in_study(
    p_study_id UUID,
    p_user_id UUID
)
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
    v_name TEXT;
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

    SELECT name INTO v_name FROM users WHERE id = p_user_id;

    -- Delete authored feedbacks/comments (comments under deleted
    -- feedbacks cascade via feedback_id FK)
    DELETE FROM feedback_comments
    WHERE study_id = p_study_id AND author_id = p_user_id;

    DELETE FROM feedbacks
    WHERE study_id = p_study_id AND author_id = p_user_id;

    -- Rewrite mentions of the departed user in surviving content
    IF v_name IS NOT NULL THEN
        PERFORM rewrite_departed_mentions(p_user_id, v_name, p_study_id);
    END IF;

    -- Delete uploaded videos (others' feedbacks/comments on them
    -- cascade via video_id FK); return IDs for storage cleanup
    RETURN QUERY
    DELETE FROM videos
    WHERE study_id = p_study_id AND uploader_id = p_user_id
    RETURNING id;
END;
$$;

-- ------------------------------------------------------------
-- 3. RPC: remove_user_content_all_studies
--    Called from delete-account Edge Function (service role).
--    Returns (study_id, video_id) of deleted videos so the Edge
--    Function can remove the storage files.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION remove_user_content_all_studies(
    p_user_id UUID
)
RETURNS TABLE(study_id UUID, video_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT name INTO v_name FROM users WHERE id = p_user_id;

    DELETE FROM feedback_comments WHERE author_id = p_user_id;

    DELETE FROM feedbacks WHERE author_id = p_user_id;

    IF v_name IS NOT NULL THEN
        PERFORM rewrite_departed_mentions(p_user_id, v_name);
    END IF;

    RETURN QUERY
    DELETE FROM videos v
    WHERE v.uploader_id = p_user_id
    RETURNING v.study_id, v.id;
END;
$$;

-- ------------------------------------------------------------
-- 4. Storage: study owner can delete member files when removing
--    a member (departing users delete their own files via the
--    existing owner-based policies).
-- ------------------------------------------------------------

CREATE POLICY "Study owner can delete member files"
    ON storage.objects FOR DELETE
    USING (
        bucket_id IN ('videos', 'thumbnails')
        AND EXISTS (
            SELECT 1 FROM studies
            WHERE id = (storage.foldername(name))[1]::uuid
              AND owner_id = auth.uid()
        )
    );
