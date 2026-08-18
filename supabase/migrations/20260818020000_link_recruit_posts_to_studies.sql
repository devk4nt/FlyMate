-- 모집 글에서 생성한 스터디방을 영구적으로 연결한다.
ALTER TABLE recruit_posts
ADD COLUMN study_id UUID REFERENCES studies(id) ON DELETE SET NULL;

CREATE INDEX idx_recruit_posts_study_id
ON recruit_posts(study_id)
WHERE study_id IS NOT NULL;

-- 작성자는 본인이 소유한 스터디만 모집 글에 연결할 수 있다.
DROP POLICY IF EXISTS "Authors can update own recruit posts" ON recruit_posts;

CREATE POLICY "Authors can update own recruit posts"
    ON recruit_posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = author_id)
    WITH CHECK (
        auth.uid() = author_id
        AND (
            study_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM studies
                WHERE studies.id = recruit_posts.study_id
                  AND studies.owner_id = auth.uid()
            )
        )
    );
