-- ------------------------------------------------------------
-- 영상 버킷 private 전환
-- 기존: public 버킷 + getPublicURL → URL만 알면 누구나 무기한 다운로드 가능.
-- 변경: private 버킷 + 서명 URL(1시간 만료). 서명 URL 발급은
--       storage.objects SELECT 권한을 요구하므로 스터디 멤버만 가능.
-- ------------------------------------------------------------

UPDATE storage.buckets SET public = false WHERE id = 'videos';

CREATE POLICY "Study members can read study videos"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'videos'
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_id = (storage.foldername(name))[1]::uuid
              AND user_id = auth.uid()
        )
    );

-- 기존 rows의 video_url(public URL)을 스토리지 경로로 정규화.
-- 클라이언트는 이 컬럼 대신 {study_id}/{id}.mp4 경로를 재구성해 서명한다.
UPDATE videos
SET video_url = study_id || '/' || id || '.mp4'
WHERE video_url LIKE 'http%';
