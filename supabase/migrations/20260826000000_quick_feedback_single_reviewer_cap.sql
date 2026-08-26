-- 빠른 피드백 영상 노출 완화(A′): claim 시 viewer_count 상한 6 → 1
--
-- 배정된 리뷰어에게만 노출되어야 하는 요청 영상이 최대 6명에게 signed URL로
-- 열리던 것을, 평생 1명만 claim 가능하도록 제한한다. claim마다 viewer_count가
-- +1 되고 1인 1회만 claim되므로 viewer_count = 영상을 본 서로 다른 리뷰어 수.
-- 서버 전용 변경 — 앱 코드 변화 없음(초과 claim은 기존과 동일하게
-- quick_feedback_unavailable 로 거절). 진짜 "배정 1인 전용"은 후속 재설계(B)에서.
--
-- ⚠️ 배포본 기준으로 재정의(리포 마이그레이션과 달랐음): claim RPC는 ad-hoc으로
-- uploader_profile_url + thumbnail_url 를 반환한다. 이 정의를 기준선으로 유지할 것.

CREATE OR REPLACE FUNCTION public.claim_quick_feedback_request(p_request_id uuid)
 RETURNS TABLE(assignment_id uuid, id uuid, uploader_id uuid, uploader_name text, uploader_profile_url text, title text, video_path text, thumbnail_url text, duration_seconds double precision, focus_area text, feedback_request text, status text, feedback_count integer, target_feedback_count integer, expires_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    request_row quick_feedback_requests;
    new_assignment_id UUID;
BEGIN
    PERFORM reconcile_quick_feedback_requests();

    SELECT * INTO request_row
    FROM quick_feedback_requests request
    WHERE request.id = p_request_id
    FOR UPDATE;

    IF request_row.id IS NULL
       OR request_row.status <> 'open'
       OR request_row.expires_at <= now()
       OR request_row.viewer_count >= 1
       OR request_row.uploader_id = auth.uid()
       OR (
            SELECT count(*)
            FROM quick_feedback_assignments active_assignment
            WHERE active_assignment.request_id = p_request_id
              AND active_assignment.status = 'active'
              AND active_assignment.expires_at > now()
       ) >= (request_row.target_feedback_count - request_row.feedback_count)
       OR (
            SELECT count(*)
            FROM quick_feedback_assignments abandoned_assignment
            WHERE abandoned_assignment.reviewer_id = auth.uid()
              AND abandoned_assignment.status = 'expired'
              AND abandoned_assignment.created_at >= now() - interval '7 days'
       ) >= 3
       OR EXISTS (
            SELECT 1 FROM quick_feedback_assignments assignment
            WHERE assignment.request_id = p_request_id
              AND assignment.reviewer_id = auth.uid()
       )
       OR EXISTS (
            SELECT 1 FROM blocked_users block
            WHERE (block.blocker_id = auth.uid() AND block.blocked_id = request_row.uploader_id)
               OR (block.blocker_id = request_row.uploader_id AND block.blocked_id = auth.uid())
       ) THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    INSERT INTO quick_feedback_assignments(request_id, reviewer_id)
    VALUES (p_request_id, auth.uid())
    RETURNING quick_feedback_assignments.id INTO new_assignment_id;

    UPDATE quick_feedback_requests
    SET viewer_count = viewer_count + 1
    WHERE quick_feedback_requests.id = p_request_id;

    RETURN QUERY SELECT
        new_assignment_id,
        request_row.id,
        request_row.uploader_id,
        request_row.uploader_name,
        request_row.uploader_profile_url,
        request_row.title,
        request_row.video_path,
        request_row.thumbnail_url,
        request_row.duration_seconds,
        request_row.focus_area,
        request_row.feedback_request,
        request_row.status,
        request_row.feedback_count,
        request_row.target_feedback_count,
        request_row.expires_at,
        request_row.created_at;
END;
$function$;
