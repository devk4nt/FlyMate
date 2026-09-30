-- 빠른 피드백: 슬롯 예약제 → 공개 풀(pool) 방식으로 전환
--
-- 기존: 한 명이 claim하면 viewer_count=1이 되어 목록에서 사라지고, 30분 배정이
--       만료되면 그 요청은 해당 리뷰어에게 영구히 재노출되지 않았다.
--       (리뷰 제출 0건 / 배정 6건 전부 expired 로 확인됨)
-- 변경: 요청은 만료되거나 목표 피드백 수를 채울 때까지 모두에게 계속 보인다.
--       피드백을 완료한 사람에게만 목록에서 빠진다.

-- 1) 목록: viewer_count 게이트 제거, 내가 이미 쓴 요청만 제외
CREATE OR REPLACE FUNCTION public.list_available_quick_feedback_requests(p_limit integer DEFAULT 20)
RETURNS TABLE(id uuid, title text, focus_area text, duration_seconds double precision, feedback_count integer, target_feedback_count integer, expires_at timestamp with time zone, created_at timestamp with time zone)
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
      AND request.feedback_count < request.target_feedback_count
      AND request.uploader_id <> auth.uid()
      AND NOT EXISTS (
            SELECT 1 FROM quick_feedback_reviews review
            WHERE review.request_id = request.id
              AND review.reviewer_id = auth.uid()
      )
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

-- 2) claim: 예약 슬롯/방치 페널티 제거, 재진입 시 기존 배정 되살림
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
       OR request_row.feedback_count >= request_row.target_feedback_count
       OR request_row.uploader_id = auth.uid()
       OR EXISTS (
            SELECT 1 FROM quick_feedback_reviews review
            WHERE review.request_id = p_request_id
              AND review.reviewer_id = auth.uid()
       )
       OR EXISTS (
            SELECT 1 FROM blocked_users block
            WHERE (block.blocker_id = auth.uid() AND block.blocked_id = request_row.uploader_id)
               OR (block.blocker_id = request_row.uploader_id AND block.blocked_id = auth.uid())
       ) THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    -- 이탈 후 재진입: 기존 배정을 되살려 재사용한다 (새로 만들면 유니크 제약에 걸린다)
    SELECT assignment.id INTO new_assignment_id
    FROM quick_feedback_assignments assignment
    WHERE assignment.request_id = p_request_id
      AND assignment.reviewer_id = auth.uid()
    FOR UPDATE;

    IF new_assignment_id IS NULL THEN
        INSERT INTO quick_feedback_assignments(request_id, reviewer_id, expires_at)
        VALUES (p_request_id, auth.uid(), request_row.expires_at)
        RETURNING quick_feedback_assignments.id INTO new_assignment_id;

        -- viewer_count는 이제 게이트가 아니라 "몇 명이 열어봤나" 지표로만 쓴다
        UPDATE quick_feedback_requests
        SET viewer_count = viewer_count + 1
        WHERE quick_feedback_requests.id = p_request_id;
    ELSE
        UPDATE quick_feedback_assignments
        SET status = 'active', expires_at = request_row.expires_at
        WHERE quick_feedback_assignments.id = new_assignment_id;
    END IF;

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

-- 3) reconcile: viewer_count>=6 자동 종료 제거 (예약제가 없어져 조기 종료만 유발함)
CREATE OR REPLACE FUNCTION public.reconcile_quick_feedback_requests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    expired_request RECORD;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    INSERT INTO quick_feedback_wallets(user_id, balance)
    VALUES (auth.uid(), 2)
    ON CONFLICT (user_id) DO NOTHING;

    -- 배정 수명 = 요청 수명이므로, 만료 표시만 하고 슬롯 반납은 하지 않는다
    UPDATE quick_feedback_assignments
    SET status = 'expired'
    WHERE status = 'active'
      AND expires_at <= now();

    FOR expired_request IN
        SELECT id, target_feedback_count - feedback_count AS refund
        FROM quick_feedback_requests
        WHERE uploader_id = auth.uid()
          AND status = 'open'
          AND expires_at <= now()
        FOR UPDATE
    LOOP
        UPDATE quick_feedback_requests
        SET status = 'expired', closed_at = now()
        WHERE id = expired_request.id;

        UPDATE quick_feedback_wallets
        SET balance = balance + expired_request.refund, updated_at = now()
        WHERE user_id = auth.uid();
    END LOOP;
END;
$function$;

-- 4) 기존 배정 수명을 요청 만료까지로 늘려, 30분 예약제에 잠긴 사용자를 푼다
UPDATE quick_feedback_assignments assignment
SET status = 'active', expires_at = request.expires_at
FROM quick_feedback_requests request
WHERE request.id = assignment.request_id
  AND assignment.status = 'expired'
  AND assignment.completed_at IS NULL
  AND request.status = 'open'
  AND request.expires_at > now();
