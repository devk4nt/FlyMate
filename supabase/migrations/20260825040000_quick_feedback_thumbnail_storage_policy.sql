-- 빠른 피드백 썸네일 업로드 경로(quick/{userID}/{requestID}.jpg) Storage 정책 추가.
-- 기존 INSERT 정책은 스터디 경로({studyID}/...)만 허용해 quick/ 업로드가 막혀 있었다.
-- 또한 기존 정책의 ::uuid 캐스트가 non-UUID 첫 폴더('quick')에서 에러를 일으키므로
-- delete 정책과 동일한 regex 가드(CASE)로 보강한다.

DROP POLICY IF EXISTS "Study members can upload thumbnails" ON storage.objects;
CREATE POLICY "Study members can upload thumbnails"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'thumbnails'
    AND CASE
        WHEN (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN is_study_member(((storage.foldername(name))[1])::uuid)
        ELSE false
    END
);

CREATE POLICY "Users can upload quick feedback thumbnails"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'thumbnails'
    AND (storage.foldername(name))[1] = 'quick'
    AND (storage.foldername(name))[2] = auth.uid()::text
);
