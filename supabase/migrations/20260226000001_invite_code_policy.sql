-- ============================================================
-- 초대코드 유효성 정책: 기간 제한 + 사용 횟수 제한 + 수동 비활성화
-- ============================================================

-- 1. 컬럼 추가 (expires_at은 backfill 후 NOT NULL로 전환)
ALTER TABLE studies
    ADD COLUMN invite_code_expires_at TIMESTAMPTZ,
    ADD COLUMN invite_code_max_use_count INT NOT NULL DEFAULT 6,
    ADD COLUMN invite_code_current_use_count INT NOT NULL DEFAULT 0,
    ADD COLUMN invite_code_is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. 기존 스터디 backfill: 90일 유예, max_use_count = max_members
UPDATE studies SET
    invite_code_expires_at = now() + interval '90 days',
    invite_code_max_use_count = max_members;

-- 3. NOT NULL 제약 + 신규 행 기본값 (7일)
ALTER TABLE studies
    ALTER COLUMN invite_code_expires_at SET NOT NULL,
    ALTER COLUMN invite_code_expires_at SET DEFAULT (now() + interval '7 days');

-- 4. join RPC — 초대코드 유효성 검사 + 사용 횟수 증가
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
    v_invite_max_use INT;
    v_invite_use_count INT;
    v_invite_is_active BOOLEAN;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- invite_code로 스터디 조회 (RLS 우회)
    SELECT id, max_members,
           invite_code_expires_at, invite_code_max_use_count,
           invite_code_current_use_count, invite_code_is_active
    INTO v_study_id, v_max_members,
         v_invite_expires_at, v_invite_max_use,
         v_invite_use_count, v_invite_is_active
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

    IF v_invite_use_count >= v_invite_max_use THEN
        RAISE EXCEPTION 'INVITE_CODE_FULLY_USED';
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

    -- 초대코드 사용 횟수 증가
    UPDATE studies
    SET invite_code_current_use_count = invite_code_current_use_count + 1
    WHERE id = v_study_id;

    RETURN v_study_id;
END;
$$;

-- 5. get RPC — 초대코드 정책 필드 반환
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
        'max_use_count', s.invite_code_max_use_count,
        'current_use_count', s.invite_code_current_use_count,
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
