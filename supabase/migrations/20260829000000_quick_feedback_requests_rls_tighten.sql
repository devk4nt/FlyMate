-- 하이브리드 B ④ — quick_feedback_requests SELECT RLS를 "본인 또는 배정 리뷰어"로 조임.
--
-- ⚠️⚠️ 절대 미리 적용 금지. **하이브리드 클라(커밋 a3e208e, 풀을
-- list_available_quick_feedback_requests RPC로 조회)가 포함된 앱이 배포·확산된 뒤에만**
-- 적용할 것. 그 전에 적용하면 아직 `.from(quick_feedback_requests).select()` 로 풀을
-- 읽는 구버전 앱의 "대기 영상" 목록이 빈 화면이 된다(크래시는 아님).
--
-- 풀 브라우징은 SECURITY DEFINER RPC(list_available_quick_feedback_requests)가,
-- claim은 SECURITY DEFINER RPC(claim_quick_feedback_request)가 담당하므로 이 정책이
-- 조여져도 정상 동작한다. 배정(claim)된 리뷰어는 assignment 존재로 요청 전체를 읽을 수 있다.

DROP POLICY IF EXISTS "Authenticated users can read quick feedback request metadata"
    ON quick_feedback_requests;

CREATE POLICY "Uploader or assigned reviewer can read quick feedback request"
    ON quick_feedback_requests FOR SELECT TO authenticated
    USING (
        auth.uid() = uploader_id
        OR EXISTS (
            SELECT 1 FROM quick_feedback_assignments assignment
            WHERE assignment.request_id = quick_feedback_requests.id
              AND assignment.reviewer_id = auth.uid()
        )
    );

NOTIFY pgrst, 'reload schema';
