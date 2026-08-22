-- 빠른 피드백 방치(미제출 이탈) 정책 완화 — 저볼륨 환경 대응
-- 1) 만료된 배정의 열람 슬롯(viewer_count) 반납 (기존엔 신고/차단 취소만 반납)
-- 2) 방치했던 영상 재배정 허용 (cancelled = 신고/차단은 계속 차단)
-- 3) 배정 만료 후에도 요청이 열려 있으면 늦은 제출 허용 (작성한 글이 날아가지 않도록)

CREATE OR REPLACE FUNCTION reconcile_quick_feedback_requests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    expired_request RECORD;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    INSERT INTO quick_feedback_wallets(user_id, balance)
    VALUES (auth.uid(), 2)
    ON CONFLICT (user_id) DO NOTHING;

    -- 만료 배정 정리는 전체 사용자 대상으로 수행한다.
    -- (본인 것만 정리하면 방치한 사용자가 재접속하지 않는 한 슬롯이 영영 반납되지 않는다)
    WITH newly_expired AS (
        UPDATE quick_feedback_assignments
        SET status = 'expired'
        WHERE status = 'active'
          AND expires_at <= now()
        RETURNING request_id
    ),
    refund AS (
        SELECT request_id, count(*) AS slot_count
        FROM newly_expired
        GROUP BY request_id
    )
    UPDATE quick_feedback_requests request
    SET viewer_count = GREATEST(request.feedback_count, request.viewer_count - refund.slot_count)
    FROM refund
    WHERE request.id = refund.request_id
      AND request.status = 'open';

    FOR expired_request IN
        SELECT id, target_feedback_count - feedback_count AS refund
        FROM quick_feedback_requests
        WHERE uploader_id = auth.uid()
          AND status = 'open'
          AND (expires_at <= now() OR viewer_count >= 6)
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
$$;

CREATE OR REPLACE FUNCTION claim_quick_feedback_request(p_request_id UUID)
RETURNS TABLE (
    assignment_id UUID,
    id UUID,
    uploader_id UUID,
    uploader_name TEXT,
    uploader_profile_url TEXT,
    title TEXT,
    video_path TEXT,
    duration_seconds DOUBLE PRECISION,
    focus_area TEXT,
    feedback_request TEXT,
    status TEXT,
    feedback_count INT,
    target_feedback_count INT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
       OR request_row.viewer_count >= 6
       OR request_row.uploader_id = auth.uid()
       OR (
            SELECT count(*)
            FROM quick_feedback_assignments active_assignment
            WHERE active_assignment.request_id = p_request_id
              AND active_assignment.status = 'active'
              AND active_assignment.expires_at > now()
       ) >= (request_row.target_feedback_count - request_row.feedback_count)
       -- 방치 패널티: 같은 영상 반복 방치가 아닌, 서로 다른 요청 기준으로 계산
       OR (
            SELECT count(DISTINCT abandoned_assignment.request_id)
            FROM quick_feedback_assignments abandoned_assignment
            WHERE abandoned_assignment.reviewer_id = auth.uid()
              AND abandoned_assignment.status = 'expired'
              AND abandoned_assignment.created_at >= now() - interval '7 days'
       ) >= 3
       -- 방치(expired)했던 요청은 재배정 허용, 그 외(active/completed/cancelled)는 차단
       OR EXISTS (
            SELECT 1 FROM quick_feedback_assignments assignment
            WHERE assignment.request_id = p_request_id
              AND assignment.reviewer_id = auth.uid()
              AND assignment.status <> 'expired'
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
        request_row.duration_seconds,
        request_row.focus_area,
        request_row.feedback_request,
        request_row.status,
        request_row.feedback_count,
        request_row.target_feedback_count,
        request_row.expires_at,
        request_row.created_at;
END;
$$;

CREATE OR REPLACE FUNCTION submit_quick_feedback_review(
    p_assignment_id UUID,
    p_positive_text TEXT,
    p_improvement_text TEXT,
    p_focus_area TEXT
)
RETURNS quick_feedback_reviews
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    assignment_row quick_feedback_assignments;
    request_row quick_feedback_requests;
    result quick_feedback_reviews;
    user_name TEXT;
BEGIN
    SELECT * INTO assignment_row
    FROM quick_feedback_assignments assignment
    WHERE assignment.id = p_assignment_id
    FOR UPDATE;

    IF assignment_row.id IS NULL OR assignment_row.reviewer_id <> auth.uid() THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    -- 만료(expired)된 배정도 요청이 아직 열려 있으면 늦은 제출을 허용한다.
    -- completed(이미 제출) / cancelled(신고·차단)만 차단.
    IF assignment_row.status NOT IN ('active', 'expired') THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    SELECT * INTO request_row
    FROM quick_feedback_requests request
    WHERE request.id = assignment_row.request_id
    FOR UPDATE;

    IF request_row.status <> 'open' THEN
        RAISE EXCEPTION 'quick_feedback_expired';
    END IF;

    -- 재배정 허용으로 한 요청에 배정이 여러 개 생길 수 있으므로, 리뷰어당 리뷰 1개를 보장
    IF EXISTS (
        SELECT 1 FROM quick_feedback_reviews review
        WHERE review.request_id = request_row.id
          AND review.reviewer_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    SELECT name INTO user_name FROM users WHERE id = auth.uid();

    INSERT INTO quick_feedback_reviews(
        request_id, assignment_id, reviewer_id, reviewer_name,
        positive_text, improvement_text, focus_area
    ) VALUES (
        request_row.id, assignment_row.id, auth.uid(), COALESCE(user_name, ''),
        btrim(p_positive_text), btrim(p_improvement_text), p_focus_area
    ) RETURNING * INTO result;

    UPDATE quick_feedback_assignments
    SET status = 'completed', completed_at = now()
    WHERE id = assignment_row.id;

    UPDATE quick_feedback_requests
    SET feedback_count = feedback_count + 1,
        -- 만료 배정의 늦은 제출은 슬롯이 이미 반납된 상태이므로 viewer_count >= feedback_count 불변식 유지
        viewer_count = GREATEST(viewer_count, feedback_count + 1),
        status = CASE WHEN feedback_count + 1 >= target_feedback_count THEN 'completed' ELSE status END,
        closed_at = CASE WHEN feedback_count + 1 >= target_feedback_count THEN now() ELSE closed_at END
    WHERE id = request_row.id;

    INSERT INTO notifications(
        recipient_id, type, title, body, reference_quick_feedback_request_id
    ) VALUES (
        request_row.uploader_id,
        'quick_feedback_received',
        CASE
            WHEN request_row.feedback_count + 1 >= request_row.target_feedback_count
                THEN '빠른 피드백이 모두 도착했어요'
            ELSE '새로운 빠른 피드백이 도착했어요'
        END,
        CASE
            WHEN request_row.feedback_count + 1 >= request_row.target_feedback_count
                THEN '목표한 피드백 2개를 모두 받았어요. 결과를 확인해보세요.'
            ELSE '첫 번째 피드백이 도착했어요. 내용을 확인해보세요.'
        END,
        request_row.id
    );

    INSERT INTO quick_feedback_wallets(user_id, balance)
    VALUES (auth.uid(), 3)
    ON CONFLICT (user_id) DO UPDATE
    SET balance = quick_feedback_wallets.balance + 1, updated_at = now();

    RETURN result;
END;
$$;

NOTIFY pgrst, 'reload schema';
