-- ============================================================
-- 플랜(무료/프리미엄) 개념 제거 + 초대코드 만료 제거 + 가입 경로 정비
--
-- 배경
-- 1. 구독 미출시 상태에서 모든 유저가 'free'(개설 1 / 총 참여 1 / 멤버 3)로 묶여 있었음
-- 2. 초대코드가 생성 7일 뒤 만료되는데 재발급 경로가 없어 신규 멤버를 받을 수 없었음
-- 3. study_members INSERT 정책이 열려 있어 초대·승인 없이 임의 스터디에 자기 자신을 넣을 수 있었음
-- 4. 앱이 쓰는 request_join_study → approve_join_request 경로에 참여 한도·정원 검사가 없었음
-- ============================================================

-- 1. 초대코드 만료/비활성 컬럼 제거 (재발급 UI 없이는 의미가 없음)
ALTER TABLE studies
    DROP COLUMN IF EXISTS invite_code_expires_at,
    DROP COLUMN IF EXISTS invite_code_is_active;

-- 2. 열린 INSERT 정책 제거 — 정상 경로는 모두 SECURITY DEFINER RPC
--    (create_study_with_limits / approve_join_request)
DROP POLICY IF EXISTS "Authenticated users can join studies" ON study_members;

-- 3. 미사용 RPC 제거
DROP FUNCTION IF EXISTS join_study_by_invite_code(TEXT);
DROP FUNCTION IF EXISTS get_study_by_invite_code(TEXT);
DROP FUNCTION IF EXISTS get_user_entitlements(UUID);
DROP FUNCTION IF EXISTS check_feature_limit(UUID, TEXT);

-- 4. 구독 테이블/트리거 제거 (기본 free 행만 존재, 실결제 데이터 없음)
DROP TRIGGER IF EXISTS trg_create_default_subscription ON users;
DROP FUNCTION IF EXISTS create_default_subscription();
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS subscription_plans;
DROP FUNCTION IF EXISTS update_subscriptions_updated_at();

-- 5. create_study_with_limits — 고정 한도 (개설 3 / 총 참여 5 / 멤버 최대 8)
--    AppConstants.maxOwnedStudies / maxJoinedStudies / maxStudyMembers 와 동일
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
    v_user_id UUID := auth.uid();
    v_study_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF (SELECT COUNT(*) FROM studies WHERE owner_id = v_user_id) >= 3 THEN
        RAISE EXCEPTION 'MAX_OWNED_STUDIES_REACHED';
    END IF;

    IF (SELECT COUNT(*) FROM study_members WHERE user_id = v_user_id) >= 5 THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    v_study_id := gen_random_uuid();
    INSERT INTO studies (id, name, description, owner_id, invite_code, max_members)
    VALUES (v_study_id, p_name, p_description, v_user_id, p_invite_code, LEAST(p_max_members, 8));

    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'owner');

    RETURN v_study_id;
END;
$$;

-- 6. request_join_study — 만료 검사 제거, 요청 시점에 참여 한도·정원 검사
CREATE OR REPLACE FUNCTION request_join_study(p_invite_code TEXT)
RETURNS SETOF study_join_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_max_members INT;
    v_user_id UUID := auth.uid();
    v_existing_status TEXT;
    v_request_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    SELECT id, max_members INTO v_study_id, v_max_members
    FROM studies
    WHERE invite_code = p_invite_code;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    IF EXISTS (SELECT 1 FROM study_members WHERE study_id = v_study_id AND user_id = v_user_id) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    IF (SELECT COUNT(*) FROM study_members WHERE user_id = v_user_id) >= 5 THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    IF (SELECT COUNT(*) FROM study_members WHERE study_id = v_study_id) >= v_max_members THEN
        RAISE EXCEPTION 'STUDY_FULL';
    END IF;

    SELECT status INTO v_existing_status
    FROM study_join_requests
    WHERE study_id = v_study_id AND user_id = v_user_id;

    IF v_existing_status = 'pending' THEN
        RAISE EXCEPTION 'ALREADY_REQUESTED';
    END IF;

    -- rejected/approved(승인 후 탈퇴) 잔여 행은 삭제 후 재요청 허용
    DELETE FROM study_join_requests
    WHERE study_id = v_study_id AND user_id = v_user_id;

    INSERT INTO study_join_requests (study_id, user_id, status)
    VALUES (v_study_id, v_user_id, 'pending')
    RETURNING id INTO v_request_id;

    RETURN QUERY SELECT * FROM study_join_requests WHERE id = v_request_id;
END;
$$;

-- 7. approve_join_request — 승인 시점에도 요청자 참여 한도 검사
CREATE OR REPLACE FUNCTION approve_join_request(p_request_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_user_id UUID;
    v_status TEXT;
    v_max_members INT;
BEGIN
    SELECT study_id, user_id, status
    INTO v_study_id, v_user_id, v_status
    FROM study_join_requests
    WHERE id = p_request_id;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'REQUEST_NOT_FOUND';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM studies WHERE id = v_study_id AND owner_id = auth.uid()) THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'REQUEST_ALREADY_HANDLED';
    END IF;

    SELECT max_members INTO v_max_members FROM studies WHERE id = v_study_id;
    IF (SELECT COUNT(*) FROM study_members WHERE study_id = v_study_id) >= v_max_members THEN
        RAISE EXCEPTION 'STUDY_FULL';
    END IF;

    IF (SELECT COUNT(*) FROM study_members WHERE user_id = v_user_id) >= 5 THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    UPDATE study_join_requests
    SET status = 'approved', responded_at = now()
    WHERE id = p_request_id;

    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'member');
END;
$$;
