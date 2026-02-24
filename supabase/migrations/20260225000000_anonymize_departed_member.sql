-- ============================================================
-- Migration: Anonymize departed member content
--
-- When a member leaves, is removed, or deletes their account,
-- their videos and feedbacks are preserved but anonymized:
--   - uploader_name / author_name → '탈퇴한 멤버'
--   - author_profile_url → NULL
--   - mentioned_user_ids → remove the departed user
-- ============================================================

-- ------------------------------------------------------------
-- 1. Drop CASCADE FK on videos.uploader_id and feedbacks.author_id
--    so that account deletion preserves content rows.
-- ------------------------------------------------------------

ALTER TABLE videos
    DROP CONSTRAINT videos_uploader_id_fkey;

ALTER TABLE feedbacks
    DROP CONSTRAINT feedbacks_author_id_fkey;

-- ------------------------------------------------------------
-- 2. RPC: anonymize_member_in_study
--    Called on study leave / member removal.
--    Anonymizes only content within the specific study.
--    Requires caller to be the user themselves or the study owner.
-- ------------------------------------------------------------

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

    -- Remove departed user from mentioned_user_ids in this study
    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE study_id = p_study_id
      AND p_user_id = ANY(mentioned_user_ids);
END;
$$;

-- ------------------------------------------------------------
-- 3. RPC: anonymize_user_all_studies
--    Called from delete-account Edge Function (service role).
--    Anonymizes content across ALL studies. No auth.uid() check
--    because it runs with service_role key.
-- ------------------------------------------------------------

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

    -- Remove user from all mentioned_user_ids arrays
    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids);
END;
$$;
