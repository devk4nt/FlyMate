-- 빠른 피드백: 스터디 가입 없이 2포인트로 요청하고, 유효한 피드백 1개당 1포인트를 얻는다.

CREATE TABLE quick_feedback_wallets (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    balance INT NOT NULL DEFAULT 2 CHECK (balance >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE quick_feedback_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uploader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    uploader_name TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 100),
    video_path TEXT NOT NULL UNIQUE,
    duration_seconds DOUBLE PRECISION NOT NULL CHECK (duration_seconds > 0 AND duration_seconds <= 60),
    focus_area TEXT NOT NULL CHECK (focus_area IN ('expression', 'voice', 'answer', 'overall')),
    feedback_request TEXT CHECK (feedback_request IS NULL OR char_length(feedback_request) <= 300),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'completed', 'expired', 'closed')),
    feedback_count INT NOT NULL DEFAULT 0 CHECK (feedback_count BETWEEN 0 AND 2),
    target_feedback_count INT NOT NULL DEFAULT 2 CHECK (target_feedback_count = 2),
    viewer_count INT NOT NULL DEFAULT 0 CHECK (viewer_count BETWEEN 0 AND 6),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '48 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE TABLE quick_feedback_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES quick_feedback_requests(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 minutes'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    UNIQUE(request_id, reviewer_id)
);

CREATE TABLE quick_feedback_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES quick_feedback_requests(id) ON DELETE CASCADE,
    assignment_id UUID NOT NULL UNIQUE REFERENCES quick_feedback_assignments(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewer_name TEXT NOT NULL DEFAULT '',
    positive_text TEXT NOT NULL CHECK (char_length(btrim(positive_text)) >= 20),
    improvement_text TEXT NOT NULL CHECK (char_length(btrim(improvement_text)) >= 20),
    focus_area TEXT NOT NULL CHECK (focus_area IN ('expression', 'voice', 'answer', 'overall')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(request_id, reviewer_id)
);

ALTER TABLE notifications
    ADD COLUMN reference_quick_feedback_request_id UUID
    REFERENCES quick_feedback_requests(id) ON DELETE CASCADE;

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'feedback_on_my_video',
        'mentioned_in_feedback',
        'reply_on_my_feedback',
        'mentioned_in_feedback_comment',
        'announcement',
        'quick_feedback_received'
    ));

CREATE UNIQUE INDEX idx_quick_feedback_one_active_request
    ON quick_feedback_requests(uploader_id) WHERE status = 'open';
CREATE INDEX idx_quick_feedback_open_queue
    ON quick_feedback_requests(created_at) WHERE status = 'open';
CREATE INDEX idx_quick_feedback_reviews_request
    ON quick_feedback_reviews(request_id, created_at);
CREATE INDEX idx_quick_feedback_assignments_reviewer
    ON quick_feedback_assignments(reviewer_id, status);

ALTER TABLE quick_feedback_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_feedback_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_feedback_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_feedback_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own quick feedback wallet"
    ON quick_feedback_wallets FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can read quick feedback request metadata"
    ON quick_feedback_requests FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can read own quick feedback assignments"
    ON quick_feedback_assignments FOR SELECT USING (auth.uid() = reviewer_id);

CREATE POLICY "Participants can read quick feedback reviews"
    ON quick_feedback_reviews FOR SELECT USING (
        auth.uid() = reviewer_id
        OR EXISTS (
            SELECT 1 FROM quick_feedback_requests request
            WHERE request.id = quick_feedback_reviews.request_id
              AND request.uploader_id = auth.uid()
        )
    );

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

    UPDATE quick_feedback_assignments
    SET status = 'expired'
    WHERE reviewer_id = auth.uid()
      AND status = 'active'
      AND expires_at <= now();

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

CREATE OR REPLACE FUNCTION create_quick_feedback_request(
    p_id UUID,
    p_title TEXT,
    p_video_path TEXT,
    p_duration_seconds DOUBLE PRECISION,
    p_focus_area TEXT,
    p_feedback_request TEXT DEFAULT NULL
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
        id, uploader_id, uploader_name, title, video_path,
        duration_seconds, focus_area, feedback_request
    ) VALUES (
        p_id, auth.uid(), COALESCE(user_name, ''), btrim(p_title), p_video_path,
        p_duration_seconds, p_focus_area, NULLIF(btrim(p_feedback_request), '')
    ) RETURNING * INTO result;

    RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION claim_quick_feedback_request(p_request_id UUID)
RETURNS TABLE (
    assignment_id UUID,
    id UUID,
    uploader_id UUID,
    uploader_name TEXT,
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

    INSERT INTO quick_feedback_wallets(user_id, balance)
    VALUES (auth.uid(), 3)
    ON CONFLICT (user_id) DO UPDATE
    SET balance = quick_feedback_wallets.balance + 1, updated_at = now();

    RETURN result;
END;
$$;

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

    UPDATE quick_feedback_wallets
    SET balance = balance + (request_row.target_feedback_count - request_row.feedback_count),
        updated_at = now()
    WHERE user_id = auth.uid();
END;
$$;

-- private videos 버킷의 quick/{userID}/{requestID}.mp4 경로만 본인 업로드 허용.
CREATE POLICY "Users can upload own quick feedback videos"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'videos'
        AND (storage.foldername(name))[1] = 'quick'
        AND lower((storage.foldername(name))[2]) = auth.uid()::text
    );

-- 요청자 또는 현재 배정된 검토자만 서명 URL을 발급할 수 있다.
CREATE POLICY "Participants can read quick feedback videos"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'videos'
        AND (storage.foldername(name))[1] = 'quick'
        AND EXISTS (
            SELECT 1 FROM quick_feedback_requests request
            WHERE request.video_path = name
              AND (
                  request.uploader_id = auth.uid()
                  OR EXISTS (
                      SELECT 1 FROM quick_feedback_assignments assignment
                      WHERE assignment.request_id = request.id
                        AND assignment.reviewer_id = auth.uid()
                        AND assignment.status = 'active'
                        AND assignment.expires_at > now()
                  )
              )
        )
    );

CREATE POLICY "Users can delete own quick feedback videos"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'videos'
        AND (storage.foldername(name))[1] = 'quick'
        AND lower((storage.foldername(name))[2]) = auth.uid()::text
    );

REVOKE ALL ON FUNCTION reconcile_quick_feedback_requests() FROM PUBLIC;
REVOKE ALL ON FUNCTION create_quick_feedback_request(UUID, TEXT, TEXT, DOUBLE PRECISION, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION claim_quick_feedback_request(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION submit_quick_feedback_review(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION close_quick_feedback_request(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION reconcile_quick_feedback_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION create_quick_feedback_request(UUID, TEXT, TEXT, DOUBLE PRECISION, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION claim_quick_feedback_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION submit_quick_feedback_review(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION close_quick_feedback_request(UUID) TO authenticated;
