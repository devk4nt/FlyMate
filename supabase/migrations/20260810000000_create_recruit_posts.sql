-- Migration: 스터디원 모집 탭 (recruit_posts, recruit_comments)

-- ============================================================
-- 0. reports 테이블 (supabase_schema.sql에만 있고 원격에 미적용된 환경 대비)
--    + target_type에 recruit_post / recruit_comment 추가
-- ============================================================

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(reporter_id, target_type, target_id)
);

ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_target_type_check;
ALTER TABLE reports ADD CONSTRAINT reports_target_type_check
    CHECK (target_type IN ('feedback', 'user', 'recruit_post', 'recruit_comment'));

CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_target ON reports(target_type, target_id);

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports"
    ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS "Users can read own reports" ON reports;
CREATE POLICY "Users can read own reports"
    ON reports FOR SELECT USING (auth.uid() = reporter_id);

-- ============================================================
-- 1. recruit_posts 테이블
-- ============================================================

CREATE TABLE recruit_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL,  -- FK 없음 (탈퇴 시 보존)
    author_name TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 50),
    description TEXT NOT NULL CHECK (char_length(description) BETWEEN 1 AND 2000),
    field TEXT NOT NULL CHECK (field IN ('flight_attendant', 'announcer', 'general_interview', 'speech', 'etc')),
    meeting_type TEXT NOT NULL CHECK (meeting_type IN ('online', 'offline', 'hybrid')),
    region TEXT,
    schedule TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    max_members INT NOT NULL CHECK (max_members BETWEEN 1 AND 20),
    deadline TIMESTAMPTZ NOT NULL,
    requirement TEXT NOT NULL,
    contact_method TEXT NOT NULL,
    link_url TEXT CHECK (link_url IS NULL OR link_url ~* '^https?://'),
    status TEXT NOT NULL DEFAULT 'recruiting' CHECK (status IN ('recruiting', 'closed')),
    comment_count INT NOT NULL DEFAULT 0,
    is_hidden BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    -- 오프라인 활동이 포함되면 지역 필수
    CHECK (meeting_type = 'online' OR region IS NOT NULL)
);

CREATE INDEX idx_recruit_posts_created_at ON recruit_posts(created_at DESC);
CREATE INDEX idx_recruit_posts_status ON recruit_posts(status, deadline);

-- ============================================================
-- 2. recruit_comments 테이블 (parent_id로 1단계 대댓글)
-- ============================================================

CREATE TABLE recruit_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES recruit_posts(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES recruit_comments(id) ON DELETE CASCADE,
    author_id UUID NOT NULL,
    author_name TEXT NOT NULL DEFAULT '',
    author_profile_url TEXT,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 300),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_recruit_comments_post_id ON recruit_comments(post_id, created_at);

-- 대댓글은 1단계까지만 (부모가 이미 대댓글이면 거부)
CREATE OR REPLACE FUNCTION enforce_recruit_comment_depth()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.parent_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM recruit_comments
        WHERE id = NEW.parent_id AND parent_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'REPLY_DEPTH_EXCEEDED';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recruit_comment_depth
    BEFORE INSERT ON recruit_comments
    FOR EACH ROW
    EXECUTE FUNCTION enforce_recruit_comment_depth();

-- ============================================================
-- 3. RLS
-- ============================================================

ALTER TABLE recruit_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE recruit_comments ENABLE ROW LEVEL SECURITY;

-- 숨김 글은 작성자 본인만 조회 가능
CREATE POLICY "Authenticated users can read visible recruit posts"
    ON recruit_posts FOR SELECT
    TO authenticated
    USING (NOT is_hidden OR auth.uid() = author_id);

CREATE POLICY "Users can create own recruit posts"
    ON recruit_posts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update own recruit posts"
    ON recruit_posts FOR UPDATE
    TO authenticated
    USING (auth.uid() = author_id);

CREATE POLICY "Authors can delete own recruit posts"
    ON recruit_posts FOR DELETE
    TO authenticated
    USING (auth.uid() = author_id);

CREATE POLICY "Authenticated users can read recruit comments"
    ON recruit_comments FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Users can create own recruit comments"
    ON recruit_comments FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can delete own recruit comments"
    ON recruit_comments FOR DELETE
    TO authenticated
    USING (auth.uid() = author_id);

-- ============================================================
-- 4. Trigger: comment_count 자동 증감
-- ============================================================

CREATE OR REPLACE FUNCTION update_recruit_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE recruit_posts
        SET comment_count = comment_count + 1
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE recruit_posts
        SET comment_count = comment_count - 1
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_recruit_comment_count
    AFTER INSERT OR DELETE ON recruit_comments
    FOR EACH ROW
    EXECUTE FUNCTION update_recruit_comment_count();

-- ============================================================
-- 5. Trigger: 내용 수정 시 updated_at 기록 ('수정됨' 표시용)
--    (status/comment_count 변경은 수정으로 치지 않음)
-- ============================================================

CREATE OR REPLACE FUNCTION touch_recruit_post_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recruit_post_updated_at
    BEFORE UPDATE OF title, description, field, meeting_type, region,
        schedule, start_date, end_date, max_members, requirement,
        contact_method, link_url
    ON recruit_posts
    FOR EACH ROW
    EXECUTE FUNCTION touch_recruit_post_updated_at();

-- ============================================================
-- 6. Trigger: 신고 5회 누적 시 모집 글 자동 숨김
--    ponytail: 댓글 자동 숨김은 운영 툴 도입 시 추가
-- ============================================================

CREATE OR REPLACE FUNCTION hide_reported_recruit_post()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.target_type = 'recruit_post' AND (
        SELECT count(*) FROM reports
        WHERE target_type = 'recruit_post' AND target_id = NEW.target_id
    ) >= 5 THEN
        UPDATE recruit_posts SET is_hidden = true WHERE id = NEW.target_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_hide_reported_recruit_post
    AFTER INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION hide_reported_recruit_post();

-- ============================================================
-- 7. PostgREST 스키마 캐시 리로드
-- ============================================================

NOTIFY pgrst, 'reload schema';
