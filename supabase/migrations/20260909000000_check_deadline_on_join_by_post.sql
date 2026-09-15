-- 모집 글 바로 가입 신청 시 마감일 검사 추가
--
-- 마감일 경과는 서버 status 변경 없이 표시/필터 레벨에서 처리하는 정책이라
-- (RecruitPost.isRecruiting = status + deadline), 클라이언트 배지는 '모집 마감'인데
-- request_join_study_by_post는 status만 검사해 마감일 지난 글에도 신청이 접수됐다.
-- 클라이언트(canRequestJoin)와 동일하게 deadline < now()면 RECRUIT_CLOSED로 거부한다.

CREATE OR REPLACE FUNCTION request_join_study_by_post(p_post_id UUID)
RETURNS SETOF study_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_post_status TEXT;
    v_deadline TIMESTAMPTZ;
    v_author_id UUID;
    v_user_id UUID := auth.uid();
    v_existing_status TEXT;
    v_request_id UUID;
BEGIN
    SELECT study_id, status, deadline, author_id
    INTO v_study_id, v_post_status, v_deadline, v_author_id
    FROM recruit_posts
    WHERE id = p_post_id;

    IF v_post_status IS NULL THEN
        RAISE EXCEPTION 'POST_NOT_FOUND';
    END IF;

    -- 스터디방을 아직 안 만든 모집 글은 신청받을 대상이 없다
    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'STUDY_NOT_LINKED';
    END IF;

    IF v_post_status <> 'recruiting' OR v_deadline < now() THEN
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
