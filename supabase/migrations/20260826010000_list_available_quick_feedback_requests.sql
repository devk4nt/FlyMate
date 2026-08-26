-- 하이브리드(프라이버시 강화 풀) B — 서버 1단계: 안전 컬럼만 반환하는 풀 조회 RPC
--
-- ⚠️ 아직 미배포. **심사 통과 후 첫 배포 대상** (가산적이라 현재 앱에 영향 없음).
-- 이 RPC를 쓰는 신규 앱이 확산된 뒤에야 RLS 조이기(별도 마이그레이션)를 적용할 것.
--
-- 풀 목록에서 요청자 신원/영상/썸네일/요청상세를 제외하고 title 등 비식별 정보만
-- 노출한다. 실제 영상·신원은 claim(claim_quick_feedback_request) 후에만 공개.
-- viewer_count < 1 조건으로 이미 claim된(=1인 열람 중) 요청은 풀에서 자동 제외
-- (20260826000000 의 상한 1과 정합).

CREATE OR REPLACE FUNCTION public.list_available_quick_feedback_requests(
    p_limit integer DEFAULT 20
)
RETURNS TABLE(
    id uuid,
    title text,
    focus_area text,
    duration_seconds double precision,
    feedback_count integer,
    target_feedback_count integer,
    expires_at timestamp with time zone,
    created_at timestamp with time zone
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
    SELECT
        request.id,
        request.title,
        request.focus_area,
        request.duration_seconds,
        request.feedback_count,
        request.target_feedback_count,
        request.expires_at,
        request.created_at
    FROM quick_feedback_requests request
    WHERE request.status = 'open'
      AND request.expires_at > now()
      AND request.viewer_count < 1
      AND request.uploader_id <> auth.uid()
      AND NOT has_quick_feedback_block_relationship(request.uploader_id)
      AND NOT EXISTS (
            SELECT 1 FROM reports report
            WHERE report.reporter_id = auth.uid()
              AND report.target_type = 'quick_feedback_request'
              AND report.target_id = request.id
      )
    ORDER BY request.created_at ASC
    LIMIT LEAST(GREATEST(p_limit, 1), 50);
$function$;

REVOKE ALL ON FUNCTION public.list_available_quick_feedback_requests(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_available_quick_feedback_requests(integer) TO authenticated;
