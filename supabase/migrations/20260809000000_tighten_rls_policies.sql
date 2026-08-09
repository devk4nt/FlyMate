-- ============================================================
-- 심사 전 점검에서 발견된 RLS 구멍 2개 보강
--
-- 1. feedbacks INSERT: 인증(auth.uid() = author_id)만 확인하고
--    스터디 멤버십을 검증하지 않아, 비멤버도 video_id만 알면
--    피드백을 삽입할 수 있었다. study_id는 클라이언트가 보낸 값을
--    신뢰할 수 없으므로(트리거는 zero-UUID일 때만 채움) video_id를
--    통해 멤버십을 검증한다. (feedback_comments는 이미 검증함)
--
-- 2. profile-images INSERT: 경로 검증이 없어 아직 파일이 없는
--    다른 유저의 경로({userID}.jpg)를 선점할 수 있었다.
-- ============================================================

DROP POLICY IF EXISTS "Study members can create feedbacks" ON feedbacks;

CREATE POLICY "Study members can create feedbacks"
    ON feedbacks FOR INSERT
    WITH CHECK (
        auth.uid() = author_id
        AND EXISTS (
            SELECT 1
            FROM videos v
            JOIN study_members sm ON sm.study_id = v.study_id
            WHERE v.id = feedbacks.video_id
              AND sm.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can upload own profile image" ON storage.objects;

-- iOS 클라이언트가 UUID를 대문자로 업로드하므로 lower()로 비교
CREATE POLICY "Users can upload own profile image"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-images'
        AND lower(name) = auth.uid()::text || '.jpg'
    );
