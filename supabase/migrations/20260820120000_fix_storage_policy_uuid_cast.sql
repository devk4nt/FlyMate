-- ------------------------------------------------------------
-- Storage RLS 정책의 uuid 캐스팅 오류 수정
--
-- 문제 1: "Study members can read study videos"가 경로 첫 폴더를 가드 없이
--   ::uuid 캐스팅. 빠른 피드백 영상 경로(quick/{userID}/{requestID}.mp4)의
--   서명 URL 발급 시 'quick' 캐스팅이 22P02로 실패해 쿼리 전체가 중단됨.
--   (RLS SELECT 정책은 OR로 함께 평가되므로 quick 정책이 허용해도 소용없음)
--
-- 문제 2: "Study owner can delete member files"가 objects.name이 아닌
--   studies.name을 참조 (서브쿼리 안에서 비한정 name이 studies.name으로
--   바인딩되는 모호성 버그) + 동일한 무가드 캐스팅.
--
-- 해결: CASE로 UUID 형식일 때만 캐스팅 (AND는 평가 순서 미보장, CASE는 보장)
-- ------------------------------------------------------------

DROP POLICY IF EXISTS "Study members can read study videos" ON storage.objects;
CREATE POLICY "Study members can read study videos"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'videos'
        AND EXISTS (
            SELECT 1 FROM study_members
            WHERE study_members.study_id = CASE
                    WHEN (storage.foldername(objects.name))[1]
                         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                    THEN ((storage.foldername(objects.name))[1])::uuid
                  END
              AND study_members.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Study owner can delete member files" ON storage.objects;
CREATE POLICY "Study owner can delete member files"
    ON storage.objects FOR DELETE
    USING (
        bucket_id IN ('videos', 'thumbnails')
        AND EXISTS (
            SELECT 1 FROM studies
            WHERE studies.id = CASE
                    WHEN (storage.foldername(objects.name))[1]
                         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                    THEN ((storage.foldername(objects.name))[1])::uuid
                  END
              AND studies.owner_id = auth.uid()
        )
    );
