-- 현직자 인증: users.is_verified 플래그 + 공개 조회 함수
--
-- 인증 여부는 인스타그램 인증 뱃지처럼 공개되는 정보다. 다만 users SELECT RLS는
-- 본인 row만 조회 가능하므로, 타인의 인증 여부를 알 수 없다.
-- 이름 등 PII는 노출하지 않고 "인증된 유저 ID 집합"만 안전하게 반환하는
-- SECURITY DEFINER 함수로 RLS를 우회한다.
-- 관리자가 메일로 재직/합격 증명을 확인한 뒤 is_verified를 수동으로 true 처리한다.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;

CREATE OR REPLACE FUNCTION get_verified_user_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT id FROM users WHERE is_verified = true;
$$;

REVOKE ALL ON FUNCTION get_verified_user_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_verified_user_ids() TO authenticated;
