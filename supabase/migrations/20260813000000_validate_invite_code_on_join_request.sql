-- request_join_study가 초대코드 만료/비활성 정책을 검사하지 않던 구멍 수정
-- (join_study_by_invite_code를 대체하면서 정책 체크가 누락됐었음)

CREATE OR REPLACE FUNCTION request_join_study(p_invite_code TEXT)
RETURNS SETOF study_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_user_id UUID := auth.uid();
    v_existing_status TEXT;
    v_request_id UUID;
    v_invite_expires_at TIMESTAMPTZ;
    v_invite_is_active BOOLEAN;
BEGIN
    -- 1. 초대 코드로 스터디 찾기
    SELECT id, invite_code_expires_at, invite_code_is_active
    INTO v_study_id, v_invite_expires_at, v_invite_is_active
    FROM studies
    WHERE invite_code = p_invite_code;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    -- 2. 초대코드 정책 검사
    IF NOT v_invite_is_active THEN
        RAISE EXCEPTION 'INVITE_CODE_INACTIVE';
    END IF;

    IF now() > v_invite_expires_at THEN
        RAISE EXCEPTION 'INVITE_CODE_EXPIRED';
    END IF;

    -- 3. 이미 멤버인지 확인
    IF EXISTS (SELECT 1 FROM study_members WHERE study_id = v_study_id AND user_id = v_user_id) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    -- 4. 기존 요청 확인
    SELECT status INTO v_existing_status
    FROM study_join_requests
    WHERE study_id = v_study_id AND user_id = v_user_id;

    IF v_existing_status = 'pending' THEN
        RAISE EXCEPTION 'ALREADY_REQUESTED';
    END IF;

    -- 5. rejected 상태면 삭제 후 재요청 허용
    IF v_existing_status = 'rejected' THEN
        DELETE FROM study_join_requests
        WHERE study_id = v_study_id AND user_id = v_user_id;
    END IF;

    -- 6. 새 pending 요청 삽입
    INSERT INTO study_join_requests (study_id, user_id, status)
    VALUES (v_study_id, v_user_id, 'pending')
    RETURNING id INTO v_request_id;

    RETURN QUERY SELECT * FROM study_join_requests WHERE id = v_request_id;
END;
$$;
