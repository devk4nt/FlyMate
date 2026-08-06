-- ============================================================
-- get_member_stats — 스터디 멤버 활동 통계 조회
-- 클라이언트: StudyRepositoryImpl.fetchMemberStats (MemberStatsResponse)
-- ============================================================

CREATE OR REPLACE FUNCTION get_member_stats(p_study_id UUID, p_user_id UUID)
RETURNS TABLE(
    user_id UUID,
    study_id UUID,
    feedback_given_count INT,
    feedback_received_count INT,
    videos_uploaded_count INT,
    joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_requester_id UUID;
    v_joined_at TIMESTAMPTZ;
BEGIN
    -- 인증 확인
    v_requester_id := auth.uid();
    IF v_requester_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 요청자가 해당 스터디 멤버인지 확인
    IF NOT EXISTS (
        SELECT 1 FROM study_members sm
        WHERE sm.study_id = p_study_id AND sm.user_id = v_requester_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 대상 유저의 가입 시각
    SELECT sm.joined_at INTO v_joined_at
    FROM study_members sm
    WHERE sm.study_id = p_study_id AND sm.user_id = p_user_id;

    IF v_joined_at IS NULL THEN
        RAISE EXCEPTION 'MEMBER_NOT_FOUND';
    END IF;

    RETURN QUERY
    SELECT
        p_user_id,
        p_study_id,
        (SELECT COUNT(*)::INT FROM feedbacks f
         WHERE f.study_id = p_study_id AND f.author_id = p_user_id),
        -- 받은 피드백: 본인이 올린 영상에 달린 피드백 (본인 작성분 제외)
        (SELECT COUNT(*)::INT FROM feedbacks f
         JOIN videos v ON v.id = f.video_id
         WHERE f.study_id = p_study_id
           AND v.uploader_id = p_user_id
           AND f.author_id <> p_user_id),
        (SELECT COUNT(*)::INT FROM videos v
         WHERE v.study_id = p_study_id AND v.uploader_id = p_user_id),
        v_joined_at;
END;
$$;
