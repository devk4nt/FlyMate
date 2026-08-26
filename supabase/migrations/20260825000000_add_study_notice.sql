-- 스터디 공지사항: studies.notice / notice_updated_at 컬럼 추가
--
-- 앱(StudyRepositoryImpl.updateNotice)은 이미 studies 테이블에 notice,
-- notice_updated_at 컬럼을 UPDATE 하지만 해당 컬럼을 추가하는 DDL이 누락되어
-- 모든 스터디장의 공지 등록이 "column does not exist" 오류로 실패해 왔다.
-- nullable 컬럼이라 기존 데이터에는 영향 없음.

ALTER TABLE studies
    ADD COLUMN IF NOT EXISTS notice TEXT,
    ADD COLUMN IF NOT EXISTS notice_updated_at TIMESTAMPTZ;

NOTIFY pgrst, 'reload schema';
