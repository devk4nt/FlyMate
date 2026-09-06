-- 모집 글에서 초대 코드 없이 바로 가입 신청
--
-- 기존에는 request_join_study(p_invite_code)가 유일한 신청 경로라, 낯선 사람이
-- 스터디에 들어가려면 모집 글에 댓글로 문의 → 작성자가 수동으로 코드 전달 →
-- 코드 참여 → 승인, 이렇게 사람 손을 두 번 거쳐야 했다. 왕복 중 한 번만
-- 끊겨도 가입이 영구히 멈춘다.
--
-- 어차피 승인은 방장이 하므로(approve_join_request) 코드를 먼저 받게 하는 것은
-- 관문을 하나 더 놓을 뿐이다. 모집 글에 연결된 스터디라면 코드 없이 신청을
-- 받고, 승인 단계는 그대로 둔다.
--
-- 참여 한도(STUDY_FULL / MAX_JOINED_STUDIES_REACHED)는 기존 신청 경로와 마찬가지로
-- 승인 시점의 approve_join_request가 검사한다. 여기서 미리 막지 않는다.

CREATE OR REPLACE FUNCTION request_join_study_by_post(p_post_id UUID)
RETURNS SETOF study_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_post_status TEXT;
    v_author_id UUID;
    v_user_id UUID := auth.uid();
    v_existing_status TEXT;
    v_request_id UUID;
BEGIN
    SELECT study_id, status, author_id
    INTO v_study_id, v_post_status, v_author_id
    FROM recruit_posts
    WHERE id = p_post_id;

    IF v_post_status IS NULL THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    -- 스터디방을 아직 안 만든 모집 글은 신청받을 대상이 없다
    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'STUDY_NOT_LINKED';
    END IF;

    IF v_post_status <> 'recruiting' THEN
        RAISE EXCEPTION 'RECRUIT_CLOSED';
    END IF;

    IF v_author_id = v_user_id THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    IF EXISTS (SELECT 1 FROM study_members WHERE study_id = v_study_id AND user_id = v_user_id) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    SELECT status INTO v_existing_status
    FROM study_join_requests
    WHERE study_id = v_study_id AND user_id = v_user_id;

    IF v_existing_status = 'pending' THEN
        RAISE EXCEPTION 'ALREADY_REQUESTED';
    END IF;

    -- rejected 는 지우고 재신청 허용 (request_join_study 와 동일)
    IF v_existing_status = 'rejected' THEN
        DELETE FROM study_join_requests
        WHERE study_id = v_study_id AND user_id = v_user_id;
    END IF;

    INSERT INTO study_join_requests (study_id, user_id, status)
    VALUES (v_study_id, v_user_id, 'pending')
    RETURNING id INTO v_request_id;

    RETURN QUERY SELECT * FROM study_join_requests WHERE id = v_request_id;
END;
$$;
