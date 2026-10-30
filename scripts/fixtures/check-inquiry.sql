-- 고객문의 검증용 읽기 전용 쿼리 (2026-08-31)
-- 1. 공지: notice 컬럼이 prod에 실제 존재하는지
select column_name from information_schema.columns
where table_name = 'studies' and column_name in ('notice', 'notice_updated_at');

-- 2. 프로필: UPDATE 정책이 참조하는 owner 컬럼이 실제로 채워지는지 (deprecated 컬럼)
select name, owner, owner_id, created_at, updated_at
from storage.objects where bucket_id = 'profile-images'
order by updated_at desc limit 5;

-- 3. profile-images 정책 전체
select policyname, cmd, qual, with_check from pg_policies
where schemaname = 'storage' and tablename = 'objects';
