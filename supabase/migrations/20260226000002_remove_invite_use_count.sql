-- ============================================================
-- 초대코드 사용 횟수 제한 제거 (기간 만료 + 비활성화만 유지)
-- ============================================================

-- 1. 사용 횟수 컬럼 제거
ALTER TABLE studies
    DROP COLUMN invite_code_max_use_count,
    DROP COLUMN invite_code_current_use_count;

-- 2. join RPC — 사용 횟수 검사/증가 로직 제거
CREATE OR REPLACE FUNCTION join_study_by_invite_code(p_invite_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_max_members INT;
    v_current_count INT;
    v_user_id UUID;
    v_invite_expires_at TIMESTAMPTZ;
    v_invite_is_active BOOLEAN;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- invite_code로 스터디 조회 (RLS 우회)
    SELECT id, max_members,
           invite_code_expires_at, invite_code_is_active
    INTO v_study_id, v_max_members,
         v_invite_expires_at, v_invite_is_active
    FROM studies
    WHERE invite_code = p_invite_code;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    -- 초대코드 유효성 검사
    IF NOT v_invite_is_active THEN
        RAISE EXCEPTION 'INVITE_CODE_INACTIVE';
    END IF;

    IF now() > v_invite_expires_at THEN
        RAISE EXCEPTION 'INVITE_CODE_EXPIRED';
    END IF;

    -- 이미 멤버인지 확인
    IF EXISTS (
        SELECT 1 FROM study_members
        WHERE study_id = v_study_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    -- 인원 초과 확인
    SELECT COUNT(*) INTO v_current_count
    FROM study_members
    WHERE study_id = v_study_id;

    IF v_current_count >= v_max_members THEN
        RAISE EXCEPTION 'STUDY_FULL';
    END IF;

    -- 멤버 추가
    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'member');

    RETURN v_study_id;
END;
$$;

-- 3. get RPC — 사용 횟수 필드 제거
CREATE OR REPLACE FUNCTION get_study_by_invite_code(p_invite_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSON;
BEGIN
    -- 인증 확인
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    SELECT json_build_object(
        'code', s.invite_code,
        'study_id', s.id,
        'study_name', s.name,
        'created_at', s.created_at,
        'expires_at', s.invite_code_expires_at,
        'is_active', s.invite_code_is_active
    ) INTO v_result
    FROM studies s
    WHERE s.invite_code = p_invite_code;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    RETURN v_result;
END;
$$;
