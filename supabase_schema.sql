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
-- NOTE: uploader_id FK has no ON DELETE CASCADE (dropped in migration 20260225000000).
--       Account deletion preserves videos; content is anonymized via RPC before deletion.
CREATE TABLE videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    uploader_id UUID NOT NULL,  -- FK constraint removed to preserve rows on account deletion
    uploader_name TEXT NOT NULL DEFAULT '',  -- DENORMALIZED, set to '탈퇴한 멤버' on departure
    title TEXT NOT NULL,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    duration_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    feedback_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feedbacks
-- NOTE: author_id FK has no ON DELETE CASCADE (dropped in migration 20260225000000).
--       Account deletion preserves feedbacks; content is anonymized via RPC before deletion.
CREATE TABLE feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    study_id UUID NOT NULL REFERENCES studies(id) ON DELETE CASCADE,
    author_id UUID NOT NULL,  -- FK constraint removed to preserve rows on account deletion
    author_name TEXT NOT NULL DEFAULT '',  -- DENORMALIZED, set to '탈퇴한 멤버' on departure
    author_profile_url TEXT,               -- DENORMALIZED, set to NULL on departure
    content TEXT NOT NULL,
    timestamp_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    mentioned_user_ids UUID[] NOT NULL DEFAULT '{}'  -- departed user is removed via array_remove
);

-- Notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('feedback_on_my_video', 'mentioned_in_feedback')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    reference_video_id UUID REFERENCES videos(id) ON DELETE CASCADE,
    reference_feedback_id UUID REFERENCES feedbacks(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Device Tokens (FCM push notifications)
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Reports (feedback/user reports)
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('feedback', 'user')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    detail TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(reporter_id, target_type, target_id)
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
CREATE INDEX idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(recipient_id) WHERE is_read = false;
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX idx_reports_target ON reports(target_type, target_id);

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

-- 3-5. Auto-create notifications on feedback insert
CREATE OR REPLACE FUNCTION create_feedback_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_video_owner_id UUID;
    v_video_title TEXT;
    v_author_name TEXT;
    v_mentioned_id UUID;
BEGIN
    -- Lookup video owner and title
    SELECT uploader_id, title INTO v_video_owner_id, v_video_title
    FROM videos WHERE id = NEW.video_id;

    -- Lookup feedback author name
    SELECT name INTO v_author_name
    FROM users WHERE id = NEW.author_id;

    -- Notify video owner (skip if author is the owner)
    IF v_video_owner_id IS NOT NULL AND v_video_owner_id != NEW.author_id THEN
        INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
        VALUES (
            v_video_owner_id,
            'feedback_on_my_video',
            '새 피드백이 달렸어요',
            v_author_name || '님이 "' || LEFT(v_video_title, 20) || '" 영상에 피드백을 남겼습니다.',
            NEW.video_id,
            NEW.id
        );
    END IF;

    -- Notify each mentioned user (skip author)
    IF array_length(NEW.mentioned_user_ids, 1) IS NOT NULL THEN
        FOREACH v_mentioned_id IN ARRAY NEW.mentioned_user_ids
        LOOP
            IF v_mentioned_id != NEW.author_id THEN
                INSERT INTO notifications (recipient_id, type, title, body, reference_video_id, reference_feedback_id)
                VALUES (
                    v_mentioned_id,
                    'mentioned_in_feedback',
                    '피드백에서 태그되었어요',
                    v_author_name || '님이 피드백에서 회원님을 태그했습니다.',
                    NEW.video_id,
                    NEW.id
                );
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_feedback_notify
    AFTER INSERT ON feedbacks
    FOR EACH ROW EXECUTE FUNCTION create_feedback_notification();

-- 3-6. Auto-update videos.feedback_count
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
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

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

-- Notifications: read own, update own (mark as read)
CREATE POLICY "Users can read own notifications"
    ON notifications FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- Device Tokens: CRUD own tokens
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own device tokens"
    ON device_tokens FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device tokens"
    ON device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device tokens"
    ON device_tokens FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own device tokens"
    ON device_tokens FOR DELETE USING (auth.uid() = user_id);

-- Reports: insert own report, read own reports
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can create reports"
    ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can read own reports"
    ON reports FOR SELECT USING (auth.uid() = reporter_id);

-- ============================================================
-- 5. REALTIME
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE feedbacks;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ============================================================
-- 6. RPC FUNCTIONS (SECURITY DEFINER — bypass RLS)
-- ============================================================

-- 6-1. Join study by invite code (atomic: validate + insert member)
CREATE OR REPLACE FUNCTION join_study_by_invite_code(p_invite_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_study_id UUID;
    v_max_members INT;
    v_current_count INT;
    v_user_id UUID;
BEGIN
    -- 인증 확인
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    -- invite_code로 스터디 조회 (RLS 우회)
    SELECT id, max_members INTO v_study_id, v_max_members
    FROM studies
    WHERE invite_code = p_invite_code;

    IF v_study_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    -- 이미 멤버인지 확인
    IF EXISTS (
        SELECT 1 FROM study_members
        WHERE study_id = v_study_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'ALREADY_MEMBER';
    END IF;

    -- 인원 초과 확인
    SELECT COUNT(*) INTO v_current_count
    FROM study_members
    WHERE study_id = v_study_id;

    IF v_current_count >= v_max_members THEN
        RAISE EXCEPTION 'STUDY_FULL';
    END IF;

    -- 멤버 추가
    INSERT INTO study_members (study_id, user_id, role)
    VALUES (v_study_id, v_user_id, 'member');

    RETURN v_study_id;
END;
$$;

-- 6-2. Get study info by invite code (for preview before joining)
CREATE OR REPLACE FUNCTION get_study_by_invite_code(p_invite_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSON;
BEGIN
    -- 인증 확인
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    SELECT json_build_object(
        'code', s.invite_code,
        'study_id', s.id,
        'study_name', s.name,
        'created_at', s.created_at
    ) INTO v_result
    FROM studies s
    WHERE s.invite_code = p_invite_code;

    IF v_result IS NULL THEN
        RAISE EXCEPTION 'INVALID_INVITE_CODE';
    END IF;

    RETURN v_result;
END;
$$;

-- 6-3. Anonymize member content within a specific study (leave / removal)
-- Caller must be the departing user or the study owner.
CREATE OR REPLACE FUNCTION anonymize_member_in_study(
    p_study_id UUID,
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF v_caller_id != p_user_id
       AND NOT EXISTS (
           SELECT 1 FROM studies
           WHERE id = p_study_id AND owner_id = v_caller_id
       )
    THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    UPDATE videos
    SET uploader_name = '탈퇴한 멤버'
    WHERE study_id = p_study_id AND uploader_id = p_user_id;

    UPDATE feedbacks
    SET author_name = '탈퇴한 멤버', author_profile_url = NULL
    WHERE study_id = p_study_id AND author_id = p_user_id;

    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE study_id = p_study_id AND p_user_id = ANY(mentioned_user_ids);
END;
$$;

-- 6-4. Anonymize user content across ALL studies (account deletion)
-- Called from delete-account Edge Function with service_role key.
CREATE OR REPLACE FUNCTION anonymize_user_all_studies(
    p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE videos
    SET uploader_name = '탈퇴한 멤버'
    WHERE uploader_id = p_user_id;

    UPDATE feedbacks
    SET author_name = '탈퇴한 멤버', author_profile_url = NULL
    WHERE author_id = p_user_id;

    UPDATE feedbacks
    SET mentioned_user_ids = array_remove(mentioned_user_ids, p_user_id)
    WHERE p_user_id = ANY(mentioned_user_ids);
END;
$$;
