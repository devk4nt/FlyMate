-- ============================================================
-- get_my_activity_stats — 본인 전체 활동 통계 조회 (설정 > 나의 활동)
-- 클라이언트: UserRepositoryImpl.fetchMyActivityStats (MyActivityStatsResponse)
-- 참여 중인 모든 스터디 합산 — 탈퇴 스터디 콘텐츠는 삭제되므로 전역 카운트와 동일
-- ============================================================

CREATE OR REPLACE FUNCTION get_my_activity_stats()
RETURNS TABLE(
    studies_count INT,
    videos_uploaded_count INT,
    feedback_received_count INT,
    feedback_given_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::INT FROM study_members sm
         WHERE sm.user_id = v_user_id),
        (SELECT COUNT(*)::INT FROM videos v
         WHERE v.uploader_id = v_user_id),
        -- 받은 피드백: 본인이 올린 영상에 달린 피드백 (본인 작성분 제외)
        (SELECT COUNT(*)::INT FROM feedbacks f
         JOIN videos v ON v.id = f.video_id
         WHERE v.uploader_id = v_user_id
           AND f.author_id <> v_user_id),
        (SELECT COUNT(*)::INT FROM feedbacks f
         WHERE f.author_id = v_user_id);
END;
$$;
