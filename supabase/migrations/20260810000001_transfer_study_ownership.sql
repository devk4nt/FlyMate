-- ============================================================
-- Migration: Study ownership transfer
--
-- 1. transfer_study_ownership RPC — 방장이 다른 멤버에게 방장 위임
-- 2. remove_user_content_all_studies 교체 — 회원 탈퇴 시 소유
--    스터디의 방장을 가장 오래된 멤버에게 자동 승계하고,
--    남은 멤버가 없으면 스터디를 삭제한다.
--    (기존에는 소유 스터디를 처리하지 않아 방장 탈퇴 시
--    스터디가 고아 상태로 남거나 FK 제약으로 탈퇴가 실패했음)
-- ============================================================

-- ------------------------------------------------------------
-- 1. RPC: transfer_study_ownership
--    호출자가 방장인 경우에만 다른 멤버에게 방장을 위임한다.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION transfer_study_ownership(
    p_study_id UUID,
    p_new_owner_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM studies
        WHERE id = p_study_id AND owner_id = v_caller_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF p_new_owner_id = v_caller_id OR NOT EXISTS (
        SELECT 1 FROM study_members
        WHERE study_id = p_study_id AND user_id = p_new_owner_id
    ) THEN
        RAISE EXCEPTION 'MEMBER_NOT_FOUND';
    END IF;

    UPDATE studies SET owner_id = p_new_owner_id WHERE id = p_study_id;
    UPDATE study_members SET role = 'owner'
    WHERE study_id = p_study_id AND user_id = p_new_owner_id;
    UPDATE study_members SET role = 'member'
    WHERE study_id = p_study_id AND user_id = v_caller_id;
END;
$$;

GRANT EXECUTE ON FUNCTION transfer_study_ownership(UUID, UUID) TO authenticated;

-- ------------------------------------------------------------
-- 2. remove_user_content_all_studies (교체)
--    delete-account Edge Function에서 service role로 호출.
--    콘텐츠 삭제 후 소유 스터디의 방장을 승계/정리한다.
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
    v_owned_study_id UUID;
    v_new_owner_id UUID;
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

    -- 소유 스터디 처리: 가장 오래된 멤버에게 방장 승계, 없으면 삭제.
    -- 본인 영상은 위에서 이미 삭제·반환됐으므로 스터디 CASCADE 삭제가
    -- Storage 정리 목록을 누락시키지 않는다.
    FOR v_owned_study_id IN
        SELECT s.id FROM studies s WHERE s.owner_id = p_user_id
    LOOP
        SELECT sm.user_id INTO v_new_owner_id
        FROM study_members sm
        WHERE sm.study_id = v_owned_study_id AND sm.user_id <> p_user_id
        ORDER BY sm.joined_at ASC
        LIMIT 1;

        IF v_new_owner_id IS NULL THEN
            DELETE FROM studies s WHERE s.id = v_owned_study_id;
        ELSE
            UPDATE studies s SET owner_id = v_new_owner_id
            WHERE s.id = v_owned_study_id;
            UPDATE study_members sm SET role = 'owner'
            WHERE sm.study_id = v_owned_study_id
              AND sm.user_id = v_new_owner_id;
        END IF;
    END LOOP;
END;
$$;
