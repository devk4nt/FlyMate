-- ============================================================
-- FlyMate Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- Users (synced with Supabase Auth)
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    profile_image_url TEXT,
    provider TEXT NOT NULL DEFAULT 'apple',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Studies
CREATE TABLE studies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    max_members INT NOT NULL DEFAULT 6,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Study Members (join table)
CREATE TABLE study_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL DEFAULT '',
    profile_image_url TEXT,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(study_id, user_id)
);

-- Videos
CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    uploader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    uploader_name TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    duration_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    feedback_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feedbacks
CREATE TABLE feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL DEFAULT '',
    author_profile_url TEXT,
    content TEXT NOT NULL,
    timestamp_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    mentioned_user_id UUID REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX idx_study_members_study_id ON study_members(study_id);
CREATE INDEX idx_study_members_user_id ON study_members(user_id);
CREATE INDEX idx_studies_invite_code ON studies(invite_code);
CREATE INDEX idx_studies_owner_id ON studies(owner_id);
CREATE INDEX idx_videos_study_id ON videos(study_id);
CREATE INDEX idx_videos_uploader_id ON videos(uploader_id);
CREATE INDEX idx_videos_created_at ON videos(created_at DESC);
CREATE INDEX idx_feedbacks_video_id ON feedbacks(video_id);
CREATE INDEX idx_feedbacks_author_id ON feedbacks(author_id);
CREATE INDEX idx_feedbacks_created_at ON feedbacks(created_at DESC);

-- ============================================================
-- 3. TRIGGERS - Auto-populate denormalized fields
-- ============================================================

-- 3-1. Auto-create user profile on Supabase Auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, name, provider)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        COALESCE(
            NEW.raw_user_meta_data->>'name',
            NEW.raw_user_meta_data->>'full_name',
            'User'
        ),
        COALESCE(NEW.raw_app_meta_data->>'provider', 'unknown')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 3-2. Auto-fill study_members.user_name and profile_image_url
CREATE OR REPLACE FUNCTION fill_study_member_info()
RETURNS TRIGGER AS $$
BEGIN
    SELECT name, profile_image_url
    INTO NEW.user_name, NEW.profile_image_url
    FROM users WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_study_member_insert
    BEFORE INSERT ON study_members
    FOR EACH ROW EXECUTE FUNCTION fill_study_member_info();

-- 3-3. Auto-fill videos.uploader_name
CREATE OR REPLACE FUNCTION fill_video_uploader_name()
RETURNS TRIGGER AS $$
BEGIN
    SELECT name INTO NEW.uploader_name
    FROM users WHERE id = NEW.uploader_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_video_insert
    BEFORE INSERT ON videos
    FOR EACH ROW EXECUTE FUNCTION fill_video_uploader_name();

-- 3-4. Auto-fill feedbacks.study_id, author_name, author_profile_url
CREATE OR REPLACE FUNCTION fill_feedback_info()
RETURNS TRIGGER AS $$
BEGIN
    -- study_id from video
    IF NEW.study_id IS NULL OR NEW.study_id = '00000000-0000-0000-0000-000000000000' THEN
        SELECT study_id INTO NEW.study_id
        FROM videos WHERE id = NEW.video_id;
    END IF;

    -- author info from user
    SELECT name, profile_image_url
    INTO NEW.author_name, NEW.author_profile_url
    FROM users WHERE id = NEW.author_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_feedback_insert
    BEFORE INSERT ON feedbacks
    FOR EACH ROW EXECUTE FUNCTION fill_feedback_info();

-- 3-5. Auto-update videos.feedback_count
CREATE OR REPLACE FUNCTION update_feedback_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE videos SET feedback_count = feedback_count + 1
        WHERE id = NEW.video_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE videos SET feedback_count = feedback_count - 1
        WHERE id = OLD.video_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_feedback_count_change
    AFTER INSERT OR DELETE ON feedbacks
    FOR EACH ROW EXECUTE FUNCTION update_feedback_count();

-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE studies ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- Users: read own profile, update own profile
CREATE POLICY "Users can read own profile"
    ON users FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE USING (auth.uid() = id);

-- Studies: read if member, create if authenticated, delete if owner
CREATE POLICY "Members can read studies"
    ON studies FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = studies.id
            AND study_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can create studies"
    ON studies FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owner can update study"
    ON studies FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Owner can delete study"
    ON studies FOR DELETE USING (auth.uid() = owner_id);

-- Study Members: read if in same study, insert if authenticated, delete own or if owner
CREATE POLICY "Members can read study members"
    ON study_members FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM study_members AS sm
            WHERE sm.study_id = study_members.study_id
            AND sm.user_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can join studies"
    ON study_members FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Members can leave or owner can remove"
    ON study_members FOR DELETE USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM studies
            WHERE studies.id = study_members.study_id
            AND studies.owner_id = auth.uid()
        )
    );

-- Videos: read if study member, insert if study member, delete own
CREATE POLICY "Study members can read videos"
    ON videos FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = videos.study_id
            AND study_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Study members can upload videos"
    ON videos FOR INSERT WITH CHECK (
        auth.uid() = uploader_id
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = videos.study_id
            AND study_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Uploader can delete own video"
    ON videos FOR DELETE USING (auth.uid() = uploader_id);

-- Feedbacks: read if study member, create if study member, delete own
CREATE POLICY "Study members can read feedbacks"
    ON feedbacks FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = feedbacks.study_id
            AND study_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Study members can create feedbacks"
    ON feedbacks FOR INSERT WITH CHECK (
        auth.uid() = author_id
    );

CREATE POLICY "Author can delete own feedback"
    ON feedbacks FOR DELETE USING (auth.uid() = author_id);

-- ============================================================
-- 5. REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE feedbacks;
