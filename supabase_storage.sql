-- ============================================================
-- FlyMate Storage Setup
-- Run this in Supabase SQL Editor AFTER supabase_schema.sql
--
-- NOTE: 이 파일은 초기 셋업 스냅샷. 이후 supabase/migrations/ 가
--       source of truth. 특히 videos 버킷은 20260808000001에서
--       private으로 전환되고 공개 read 정책이 제거되었다.
-- ============================================================

-- ============================================================
-- 1. CREATE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    ('videos', 'videos', true, 524288000, ARRAY['video/mp4', 'video/quicktime']),
    ('thumbnails', 'thumbnails', true, 5242880, ARRAY['image/jpeg', 'image/png']),
    ('profile-images', 'profile-images', true, 5242880, ARRAY['image/jpeg', 'image/png']);

-- videos: 500MB limit, mp4/mov only
-- thumbnails: 5MB limit, jpeg/png
-- profile-images: 5MB limit, jpeg/png

-- ============================================================
-- 2. STORAGE RLS POLICIES
-- ============================================================

-- ----------------------------------------
-- videos bucket
-- ----------------------------------------

-- Anyone can read (public bucket)
CREATE POLICY "Public read access for videos"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'videos');

-- Study members can upload videos
CREATE POLICY "Study members can upload videos"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'videos'
        AND auth.role() = 'authenticated'
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = (storage.foldername(name))[1]::uuid
            AND study_members.user_id = auth.uid()
        )
    );

-- Uploader can delete own video files
CREATE POLICY "Users can delete own video files"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'videos'
        AND auth.uid() = owner
    );

-- ----------------------------------------
-- thumbnails bucket
-- ----------------------------------------

CREATE POLICY "Public read access for thumbnails"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'thumbnails');

CREATE POLICY "Study members can upload thumbnails"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'thumbnails'
        AND auth.role() = 'authenticated'
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = (storage.foldername(name))[1]::uuid
            AND study_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own thumbnail files"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'thumbnails'
        AND auth.uid() = owner
    );

-- ----------------------------------------
-- profile-images bucket
-- ----------------------------------------

CREATE POLICY "Public read access for profile images"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-images');

-- Users can upload/overwrite own profile image (path: {userID}.jpg)
-- iOS 클라이언트가 UUID를 대문자로 업로드하므로 lower()로 비교
CREATE POLICY "Users can upload own profile image"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-images'
        AND lower(name) = auth.uid()::text || '.jpg'
    );

CREATE POLICY "Users can update own profile image"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'profile-images'
        AND auth.uid() = owner
    );

CREATE POLICY "Users can delete own profile image"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'profile-images'
        AND auth.uid() = owner
    );
