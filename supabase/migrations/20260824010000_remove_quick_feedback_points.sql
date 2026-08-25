-- 빠른 피드백 포인트(지갑) 제도 제거 — 업로드 진입장벽 철폐.
-- create: 포인트 차감/부족 체크 제거. submit: 적립(+1) 제거. close: 환급 제거.
-- quick_feedback_wallets 테이블은 드롭하지 않고 휴면 상태로 남긴다(비가역 방지, 추후 복구 용이).

-- create: 차감/insufficient 체크 없이 요청만 생성 (thumbnail_url 파라미터 유지)
CREATE OR REPLACE FUNCTION create_quick_feedback_request(
    p_id UUID,
    p_title TEXT,
    p_video_path TEXT,
    p_duration_seconds DOUBLE PRECISION,
    p_focus_area TEXT,
    p_feedback_request TEXT DEFAULT NULL,
    p_thumbnail_url TEXT DEFAULT NULL
)
RETURNS quick_feedback_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result quick_feedback_requests;
    user_name TEXT;
BEGIN
    PERFORM reconcile_quick_feedback_requests();

    IF EXISTS (
        SELECT 1 FROM quick_feedback_requests
        WHERE uploader_id = auth.uid() AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'active_quick_feedback_exists';
    END IF;

    SELECT name INTO user_name FROM users WHERE id = auth.uid();

    INSERT INTO quick_feedback_requests(
        id, uploader_id, uploader_name, title, video_path, thumbnail_url,
        duration_seconds, focus_area, feedback_request
    ) VALUES (
        p_id, auth.uid(), COALESCE(user_name, ''), btrim(p_title), p_video_path, p_thumbnail_url,
        p_duration_seconds, p_focus_area, NULLIF(btrim(p_feedback_request), '')
    ) RETURNING * INTO result;

    RETURN result;
END;
$$;

-- submit: 리뷰 적립(+1 wallet) 제거
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

    IF assignment_row.status <> 'active' OR assignment_row.expires_at <= now() THEN
        UPDATE quick_feedback_assignments
        SET status = 'expired'
        WHERE id = p_assignment_id AND status = 'active';
        RAISE EXCEPTION 'quick_feedback_expired';
    END IF;

    SELECT * INTO request_row
    FROM quick_feedback_requests request
    WHERE request.id = assignment_row.request_id
    FOR UPDATE;

    IF request_row.status <> 'open' THEN
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

    RETURN result;
END;
$$;

-- close: 미수령 피드백 환급 제거
CREATE OR REPLACE FUNCTION close_quick_feedback_request(p_request_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    request_row quick_feedback_requests;
BEGIN
    SELECT * INTO request_row
    FROM quick_feedback_requests request
    WHERE request.id = p_request_id AND request.uploader_id = auth.uid()
    FOR UPDATE;

    IF request_row.id IS NULL OR request_row.status <> 'open' THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    UPDATE quick_feedback_requests
    SET status = 'closed', closed_at = now()
    WHERE id = p_request_id;
END;
$$;
