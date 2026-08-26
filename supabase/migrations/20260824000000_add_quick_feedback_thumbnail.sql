-- 빠른 피드백 요청에 썸네일(공개 URL) 추가 — 허브 카드 리스트 미리보기용.
-- videos 테이블과 동일하게 thumbnail_url에 public URL 문자열을 저장한다(서명 불필요).

ALTER TABLE quick_feedback_requests
    ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- create RPC: p_thumbnail_url 파라미터 추가 (기존 시그니처 뒤에 DEFAULT NULL로 확장)
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

    UPDATE quick_feedback_wallets
    SET balance = balance - 2, updated_at = now()
    WHERE user_id = auth.uid() AND balance >= 2;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'insufficient_feedback_points';
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

-- claim RPC: RETURNS TABLE에 thumbnail_url 추가 (반환 타입 변경 → DROP 후 재생성, 같은 트랜잭션이라 무중단)
DROP FUNCTION IF EXISTS claim_quick_feedback_request(UUID);
CREATE OR REPLACE FUNCTION claim_quick_feedback_request(p_request_id UUID)
RETURNS TABLE (
    assignment_id UUID,
    id UUID,
    uploader_id UUID,
    uploader_name TEXT,
    uploader_profile_url TEXT,
    title TEXT,
    video_path TEXT,
    thumbnail_url TEXT,
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
$$;
