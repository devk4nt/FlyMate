-- ============================================================
-- 스터디 참여 제한 정책: Owner 최대 3개, 총 참여 최대 5개
-- ============================================================

-- 1. join_study_by_invite_code — 총 참여 수 검증 추가
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
    v_total_joined INT;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 총 참여 스터디 수 확인 (최대 5개)
    SELECT COUNT(*) INTO v_total_joined
    FROM study_members
    WHERE user_id = v_user_id;

    IF v_total_joined >= 5 THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
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

-- 2. create_study_with_limits — 원자적 스터디 생성 + 제한 검증
CREATE OR REPLACE FUNCTION create_study_with_limits(
    p_name TEXT,
    p_description TEXT,
    p_max_members INT,
    p_invite_code TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_owned_count INT;
    v_total_joined INT;
    v_study_id UUID;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 방장으로 생성한 스터디 수 확인 (최대 3개)
    SELECT COUNT(*) INTO v_owned_count
    FROM studies
    WHERE owner_id = v_user_id;

    IF v_owned_count >= 3 THEN
        RAISE EXCEPTION 'MAX_OWNED_STUDIES_REACHED';
    END IF;

    -- 총 참여 스터디 수 확인 (최대 5개)
    SELECT COUNT(*) INTO v_total_joined
    FROM study_members
    WHERE user_id = v_user_id;

    IF v_total_joined >= 5 THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    -- 스터디 생성
    v_study_id := gen_random_uuid();
    INSERT INTO studies (id, name, description, owner_id, invite_code, max_members)
    VALUES (v_study_id, p_name, p_description, v_user_id, p_invite_code, p_max_members);

    -- 소유자를 멤버로 추가
    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'owner');

    RETURN v_study_id;
END;
$$;
