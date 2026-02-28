-- ============================================================
-- 구독 시스템: subscription_plans + subscriptions 테이블
-- 무료/프리미엄 2단계 플랜, App Store 서버 검증 기반
-- ============================================================

-- 1. subscription_plans — 플랜별 제한값 정의
CREATE TABLE subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    max_owned_studies INT NOT NULL,
    max_joined_studies INT NOT NULL,
    max_video_duration_seconds INT NOT NULL,
    max_study_members INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO subscription_plans (id, name, max_owned_studies, max_joined_studies, max_video_duration_seconds, max_study_members)
VALUES
    ('free', '무료', 1, 1, 60, 3),
    ('premium_monthly', '프리미엄 (월간)', 5, 5, 600, 8),
    ('premium_yearly', '프리미엄 (연간)', 5, 5, 600, 8);

-- 2. subscriptions — 사용자별 구독 상태
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL DEFAULT 'free' REFERENCES subscription_plans(id),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'expired', 'revoked', 'grace_period', 'billing_retry')),
    original_transaction_id TEXT,
    latest_transaction_id TEXT,
    product_id TEXT,
    environment TEXT DEFAULT 'production'
        CHECK (environment IN ('production', 'sandbox')),
    purchase_date TIMESTAMPTZ,
    expires_date TIMESTAMPTZ,
    renewal_date TIMESTAMPTZ,
    is_in_billing_retry BOOLEAN NOT NULL DEFAULT false,
    auto_renew_status BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_original_transaction_id ON subscriptions(original_transaction_id);

-- 3. RLS 정책
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- subscription_plans: 누구나 조회 가능
CREATE POLICY "Anyone can read subscription plans"
    ON subscription_plans FOR SELECT
    USING (true);

-- subscriptions: 본인 구독만 조회
CREATE POLICY "Users can read own subscription"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- subscriptions: INSERT/UPDATE는 service_role만 (Edge Function에서 처리)
-- RLS가 활성화되어 있으므로 일반 사용자는 INSERT/UPDATE 불가
-- service_role key를 사용하는 Edge Function은 RLS를 우회

-- 4. updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_subscriptions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_subscriptions_updated_at();

-- 5. 신규 유저 가입 시 free 구독 자동 생성
CREATE OR REPLACE FUNCTION create_default_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO subscriptions (user_id, plan_id, status)
    VALUES (NEW.id, 'free', 'active')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_default_subscription
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_default_subscription();

-- 6. 기존 유저 backfill
INSERT INTO subscriptions (user_id, plan_id, status)
SELECT id, 'free', 'active'
FROM users
ON CONFLICT (user_id) DO NOTHING;

-- 7. get_user_entitlements — 사용자 권한 + 현재 사용량 JSON 반환
CREATE OR REPLACE FUNCTION get_user_entitlements(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan_id TEXT;
    v_status TEXT;
    v_expires_date TIMESTAMPTZ;
    v_plan RECORD;
    v_owned_count INT;
    v_joined_count INT;
    v_result JSON;
BEGIN
    -- 구독 정보 조회
    SELECT s.plan_id, s.status, s.expires_date
    INTO v_plan_id, v_status, v_expires_date
    FROM subscriptions s
    WHERE s.user_id = p_user_id;

    -- 구독이 없으면 free 기본값
    IF v_plan_id IS NULL THEN
        v_plan_id := 'free';
        v_status := 'active';
    END IF;

    -- 만료된 프리미엄은 free로 취급
    IF v_plan_id != 'free' AND v_status NOT IN ('active', 'grace_period', 'billing_retry') THEN
        v_plan_id := 'free';
    END IF;

    -- 플랜 제한값 조회
    SELECT * INTO v_plan
    FROM subscription_plans
    WHERE id = v_plan_id;

    -- 현재 사용량 조회
    SELECT COUNT(*) INTO v_owned_count
    FROM studies
    WHERE owner_id = p_user_id;

    SELECT COUNT(*) INTO v_joined_count
    FROM study_members
    WHERE user_id = p_user_id;

    v_result := json_build_object(
        'plan_id', v_plan_id,
        'status', v_status,
        'expires_date', v_expires_date,
        'max_owned_studies', v_plan.max_owned_studies,
        'max_joined_studies', v_plan.max_joined_studies,
        'max_video_duration_seconds', v_plan.max_video_duration_seconds,
        'max_study_members', v_plan.max_study_members,
        'current_owned_studies', v_owned_count,
        'current_joined_studies', v_joined_count
    );

    RETURN v_result;
END;
$$;

-- 8. check_feature_limit — 개별 기능 제한 확인
CREATE OR REPLACE FUNCTION check_feature_limit(p_user_id UUID, p_feature TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_entitlements JSON;
    v_allowed BOOLEAN;
    v_current INT;
    v_max INT;
BEGIN
    v_entitlements := get_user_entitlements(p_user_id);

    CASE p_feature
        WHEN 'create_study' THEN
            v_current := (v_entitlements->>'current_owned_studies')::INT;
            v_max := (v_entitlements->>'max_owned_studies')::INT;
            v_allowed := v_current < v_max;
        WHEN 'join_study' THEN
            v_current := (v_entitlements->>'current_joined_studies')::INT;
            v_max := (v_entitlements->>'max_joined_studies')::INT;
            v_allowed := v_current < v_max;
        ELSE
            v_allowed := true;
            v_current := 0;
            v_max := 0;
    END CASE;

    RETURN json_build_object(
        'allowed', v_allowed,
        'current', v_current,
        'max', v_max,
        'feature', p_feature
    );
END;
$$;

-- 9. create_study_with_limits — 구독 기반 제한으로 교체
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
    v_plan_id TEXT;
    v_status TEXT;
    v_plan RECORD;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 구독 기반 플랜 조회
    SELECT s.plan_id, s.status INTO v_plan_id, v_status
    FROM subscriptions s
    WHERE s.user_id = v_user_id;

    -- 구독이 없거나 만료 시 free 적용
    IF v_plan_id IS NULL OR (v_plan_id != 'free' AND v_status NOT IN ('active', 'grace_period', 'billing_retry')) THEN
        v_plan_id := 'free';
    END IF;

    SELECT * INTO v_plan FROM subscription_plans WHERE id = v_plan_id;

    -- 방장으로 생성한 스터디 수 확인
    SELECT COUNT(*) INTO v_owned_count
    FROM studies
    WHERE owner_id = v_user_id;

    IF v_owned_count >= v_plan.max_owned_studies THEN
        RAISE EXCEPTION 'MAX_OWNED_STUDIES_REACHED';
    END IF;

    -- 총 참여 스터디 수 확인
    SELECT COUNT(*) INTO v_total_joined
    FROM study_members
    WHERE user_id = v_user_id;

    IF v_total_joined >= v_plan.max_joined_studies THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    -- 멤버 수 제한 적용
    IF p_max_members > v_plan.max_study_members THEN
        p_max_members := v_plan.max_study_members;
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

-- 10. join_study_by_invite_code — 구독 기반 제한으로 교체
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
    v_plan_id TEXT;
    v_status TEXT;
    v_plan RECORD;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- 구독 기반 플랜 조회
    SELECT s.plan_id, s.status INTO v_plan_id, v_status
    FROM subscriptions s
    WHERE s.user_id = v_user_id;

    IF v_plan_id IS NULL OR (v_plan_id != 'free' AND v_status NOT IN ('active', 'grace_period', 'billing_retry')) THEN
        v_plan_id := 'free';
    END IF;

    SELECT * INTO v_plan FROM subscription_plans WHERE id = v_plan_id;

    -- 총 참여 스터디 수 확인
    SELECT COUNT(*) INTO v_total_joined
    FROM study_members
    WHERE user_id = v_user_id;

    IF v_total_joined >= v_plan.max_joined_studies THEN
        RAISE EXCEPTION 'MAX_JOINED_STUDIES_REACHED';
    END IF;

    -- invite_code로 스터디 조회
    SELECT id, max_members,
           invite_code_expires_at, invite_code_is_active
    INTO v_study_id, v_max_members,
         v_invite_expires_at, v_invite_is_active
    FROM studies
    WHERE invite_code = p_invite_code;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    IF NOT v_invite_is_active THEN
        RAISE EXCEPTION 'INVITE_CODE_INACTIVE';
    END IF;

    IF now() > v_invite_expires_at THEN
        RAISE EXCEPTION 'INVITE_CODE_EXPIRED';
    END IF;

    IF EXISTS (
        SELECT 1 FROM study_members
        WHERE study_id = v_study_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    SELECT COUNT(*) INTO v_current_count
    FROM study_members
    WHERE study_id = v_study_id;

    IF v_current_count >= v_max_members THEN
        RAISE EXCEPTION 'STUDY_FULL';
    END IF;

    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'member');

    RETURN v_study_id;
END;
$$;
