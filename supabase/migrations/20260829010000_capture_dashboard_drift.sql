-- 대시보드에서만 적용되어 마이그레이션에 없던 객체를 코드로 회수 (2026-08-29 staging 구축 중 prod 대조로 발견)
-- prod에는 이미 존재 — 히스토리만 등록(--mark). 새 환경(staging)에서는 실제 실행.

-- storage 정책(20260825040000)이 참조하는 헬퍼
CREATE OR REPLACE FUNCTION public.get_auth_uid()
RETURNS uuid
LANGUAGE sql
AS $$
    SELECT auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_study_member(p_study_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT EXISTS (
        SELECT 1 FROM study_members
        WHERE study_id = p_study_id
          AND user_id = auth.uid()
    );
$$;

-- 20260824000000이 p_thumbnail_url 추가 시 새 오버로드를 만들어 구 시그니처(6인자)가 남음 — prod는 수동 삭제됨
DROP FUNCTION IF EXISTS public.create_quick_feedback_request(uuid, text, text, double precision, text, text);

-- Database Webhook(notifications INSERT → send-push-notification)이 사용하는 확장
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
