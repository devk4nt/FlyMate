-- 빠른 피드백 신고/차단 지원

-- 빠른 피드백 영상 요청과 리뷰를 콘텐츠 단위로 신고할 수 있게 한다.
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE reports ADD CONSTRAINT reports_target_type_check
    CHECK (target_type IN (
        'feedback',
        'user',
        'recruit_post',
        'recruit_comment',
        'quick_feedback_request',
        'quick_feedback_review'
    ));

-- RLS 정책에서 양방향 차단 관계를 안전하게 확인한다.
CREATE OR REPLACE FUNCTION has_quick_feedback_block_relationship(p_other_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM blocked_users block
        WHERE (block.blocker_id = auth.uid() AND block.blocked_id = p_other_user_id)
           OR (block.blocker_id = p_other_user_id AND block.blocked_id = auth.uid())
    );
$$;

REVOKE ALL ON FUNCTION has_quick_feedback_block_relationship(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION has_quick_feedback_block_relationship(UUID) TO authenticated;

DROP POLICY IF EXISTS "Authenticated users can read quick feedback request metadata"
    ON quick_feedback_requests;
CREATE POLICY "Authenticated users can read quick feedback request metadata"
    ON quick_feedback_requests FOR SELECT USING (
        auth.uid() = uploader_id
        OR (
            NOT has_quick_feedback_block_relationship(uploader_id)
            AND NOT EXISTS (
                SELECT 1
                FROM reports report
                WHERE report.reporter_id = auth.uid()
                  AND report.target_type = 'quick_feedback_request'
                  AND report.target_id = quick_feedback_requests.id
            )
        )
    );

DROP POLICY IF EXISTS "Participants can read quick feedback reviews"
    ON quick_feedback_reviews;
CREATE POLICY "Participants can read quick feedback reviews"
    ON quick_feedback_reviews FOR SELECT USING (
        auth.uid() = reviewer_id
        OR (
            EXISTS (
                SELECT 1
                FROM quick_feedback_requests request
                WHERE request.id = quick_feedback_reviews.request_id
                  AND request.uploader_id = auth.uid()
            )
            AND NOT has_quick_feedback_block_relationship(reviewer_id)
            AND NOT EXISTS (
                SELECT 1
                FROM reports report
                WHERE report.reporter_id = auth.uid()
                  AND report.target_type = 'quick_feedback_review'
                  AND report.target_id = quick_feedback_reviews.id
            )
        )
    );

-- 신고 또는 차단으로 영상을 더 볼 수 없게 된 경우 배정을 페널티 없이 취소한다.
ALTER TABLE quick_feedback_assignments
    DROP CONSTRAINT IF EXISTS quick_feedback_assignments_status_check;
ALTER TABLE quick_feedback_assignments
    ADD CONSTRAINT quick_feedback_assignments_status_check
    CHECK (status IN ('active', 'completed', 'expired', 'cancelled'));

CREATE OR REPLACE FUNCTION cancel_quick_feedback_assignment(p_assignment_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    assignment_row quick_feedback_assignments;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    SELECT * INTO assignment_row
    FROM quick_feedback_assignments assignment
    WHERE assignment.id = p_assignment_id
    FOR UPDATE;

    IF assignment_row.id IS NULL OR assignment_row.reviewer_id <> auth.uid() THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    IF assignment_row.status = 'cancelled' THEN
        RETURN;
    END IF;

    IF assignment_row.status <> 'active' THEN
        RAISE EXCEPTION 'quick_feedback_unavailable';
    END IF;

    UPDATE quick_feedback_assignments
    SET status = 'cancelled'
    WHERE id = p_assignment_id;

    UPDATE quick_feedback_requests
    SET viewer_count = GREATEST(feedback_count, viewer_count - 1)
    WHERE id = assignment_row.request_id
      AND status = 'open';
END;
$$;

REVOKE ALL ON FUNCTION cancel_quick_feedback_assignment(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cancel_quick_feedback_assignment(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
