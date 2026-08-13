-- Migration: blocked_users에 차단 대상 이름 비정규화
--
-- users 테이블 SELECT RLS(본인 row만 조회 가능) 때문에 차단 목록에서
-- 차단 대상의 이름을 조회할 수 없어 "알 수 없는 사용자"로 표시되던 문제.
-- 앱의 기존 패턴(feedbacks.author_name 등)대로 차단 시점의 이름을 저장한다.

ALTER TABLE blocked_users
    ADD COLUMN blocked_name TEXT NOT NULL DEFAULT '알 수 없는 사용자';
