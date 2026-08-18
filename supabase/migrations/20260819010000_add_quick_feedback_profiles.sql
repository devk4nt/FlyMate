-- 빠른 피드백 요청자·리뷰어 프로필 이미지 스냅샷과 변경 동기화

ALTER TABLE quick_feedback_requests
ADD COLUMN IF NOT EXISTS uploader_profile_url TEXT;

ALTER TABLE quick_feedback_reviews
ADD COLUMN IF NOT EXISTS reviewer_profile_url TEXT;

UPDATE quick_feedback_requests request
SET uploader_name = app_user.name,
    uploader_profile_url = app_user.profile_image_url
FROM users app_user
WHERE app_user.id = request.uploader_id;

UPDATE quick_feedback_reviews review
SET reviewer_name = app_user.name,
    reviewer_profile_url = app_user.profile_image_url
FROM users app_user
WHERE app_user.id = review.reviewer_id;

CREATE OR REPLACE FUNCTION hydrate_quick_feedback_request_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SELECT app_user.name, app_user.profile_image_url
    INTO NEW.uploader_name, NEW.uploader_profile_url
    FROM users app_user
    WHERE app_user.id = NEW.uploader_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hydrate_quick_feedback_request_profile_trigger
ON quick_feedback_requests;
CREATE TRIGGER hydrate_quick_feedback_request_profile_trigger
    BEFORE INSERT ON quick_feedback_requests
    FOR EACH ROW
    EXECUTE FUNCTION hydrate_quick_feedback_request_profile();

CREATE OR REPLACE FUNCTION hydrate_quick_feedback_review_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SELECT app_user.name, app_user.profile_image_url
    INTO NEW.reviewer_name, NEW.reviewer_profile_url
    FROM users app_user
    WHERE app_user.id = NEW.reviewer_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hydrate_quick_feedback_review_profile_trigger
ON quick_feedback_reviews;
CREATE TRIGGER hydrate_quick_feedback_review_profile_trigger
    BEFORE INSERT ON quick_feedback_reviews
    FOR EACH ROW
    EXECUTE FUNCTION hydrate_quick_feedback_review_profile();

CREATE OR REPLACE FUNCTION sync_quick_feedback_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE quick_feedback_requests
    SET uploader_name = NEW.name,
        uploader_profile_url = NEW.profile_image_url
    WHERE uploader_id = NEW.id;

    UPDATE quick_feedback_reviews
    SET reviewer_name = NEW.name,
        reviewer_profile_url = NEW.profile_image_url
    WHERE reviewer_id = NEW.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_quick_feedback_user_profile_trigger ON users;
CREATE TRIGGER sync_quick_feedback_user_profile_trigger
    AFTER UPDATE OF name, profile_image_url ON users
    FOR EACH ROW
    WHEN (
        OLD.name IS DISTINCT FROM NEW.name
        OR OLD.profile_image_url IS DISTINCT FROM NEW.profile_image_url
    )
    EXECUTE FUNCTION sync_quick_feedback_user_profile();

-- 반환 컬럼은 CREATE OR REPLACE로 변경할 수 없어 기존 함수를 다시 생성한다.
DROP FUNCTION IF EXISTS claim_quick_feedback_request(UUID);

CREATE FUNCTION claim_quick_feedback_request(p_request_id UUID)
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

REVOKE ALL ON FUNCTION claim_quick_feedback_request(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION claim_quick_feedback_request(UUID) TO authenticated;
