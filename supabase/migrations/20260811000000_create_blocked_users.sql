-- Migration: 사용자 차단 (App Store Guideline 1.2 — UGC 앱 차단 기능)
--
-- blocked_users 테이블 + RESTRICTIVE RLS 정책으로 차단한 사용자의
-- 콘텐츠(피드백/답글/영상/모집글/모집댓글)를 서버 레벨에서 숨긴다.
-- RESTRICTIVE 정책은 기존 permissive SELECT 정책과 AND로 결합되므로
-- 기존 정책을 건드리지 않고 필터만 추가된다.

-- ============================================================
-- 1. blocked_users 테이블
-- ============================================================

CREATE TABLE blocked_users (
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL,  -- FK 없음 (차단 대상 탈퇴 시에도 보존)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
);

ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own blocks"
    ON blocked_users FOR ALL
    USING (auth.uid() = blocker_id)
    WITH CHECK (auth.uid() = blocker_id);

-- ============================================================
-- 2. 차단한 사용자의 콘텐츠 숨김 (RESTRICTIVE SELECT)
-- ============================================================

CREATE POLICY "Hide blocked users feedbacks"
    ON feedbacks AS RESTRICTIVE FOR SELECT
    USING (NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = feedbacks.author_id
    ));

CREATE POLICY "Hide blocked users feedback comments"
    ON feedback_comments AS RESTRICTIVE FOR SELECT
    USING (NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = feedback_comments.author_id
    ));

CREATE POLICY "Hide blocked users videos"
    ON videos AS RESTRICTIVE FOR SELECT
    USING (NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = videos.uploader_id
    ));

CREATE POLICY "Hide blocked users recruit posts"
    ON recruit_posts AS RESTRICTIVE FOR SELECT
    USING (NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = recruit_posts.author_id
    ));

CREATE POLICY "Hide blocked users recruit comments"
    ON recruit_comments AS RESTRICTIVE FOR SELECT
    USING (NOT EXISTS (
        SELECT 1 FROM blocked_users b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = recruit_comments.author_id
    ));
