-- ============================================================
-- 플랜/초대코드 만료 레거시 객체 제거 (파괴적 — v1.5 확산 후에만 적용)
--
-- get_study_by_invite_code는 v1.4 클라이언트가 코드 참여 화면에서 호출한다.
-- 20260829000000_quick_feedback_requests_rls_tighten.sql 과 같은 타이밍에 적용.
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

