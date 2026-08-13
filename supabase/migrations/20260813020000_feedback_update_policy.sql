-- ============================================================
-- 피드백 수정 기능: 작성자 본인의 피드백 UPDATE 정책 추가
-- (기존에 feedbacks 테이블 FOR UPDATE 정책이 없어 수정 불가 상태)
-- ============================================================

DROP POLICY IF EXISTS "Authors can update own feedbacks" ON feedbacks;

CREATE POLICY "Authors can update own feedbacks"
    ON feedbacks FOR UPDATE
    USING (auth.uid() = author_id)
    WITH CHECK (auth.uid() = author_id);
