-- 영상 업로드: videos.focus_points / feedback_request 컬럼 추가
--
-- 앱(VideoRepositoryImpl.uploadVideo의 InsertVideo)은 focus_points,
-- feedback_request 컬럼에 값을 INSERT 하지만 해당 DDL이 누락되어,
-- 사용자가 촬영 포커스/피드백 요청사항을 입력하고 업로드하면
-- "column does not exist" 오류로 실패해 왔다. (두 값이 모두 비어 있으면
-- optional 인코딩이 필드를 생략해 우연히 성공하던 상태.)
-- nullable 컬럼이라 기존 데이터에는 영향 없음.

ALTER TABLE videos
    ADD COLUMN IF NOT EXISTS focus_points TEXT,
    ADD COLUMN IF NOT EXISTS feedback_request TEXT;

NOTIFY pgrst, 'reload schema';
