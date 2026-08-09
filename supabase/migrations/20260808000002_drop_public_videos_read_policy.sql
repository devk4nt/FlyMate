-- 초기 설정 때 만든 공개 read 정책 제거.
-- 남아 있으면 스터디 멤버가 아니어도 서명 URL 발급이 가능해
-- private 버킷 전환(20260808000001)이 무력화된다.
DROP POLICY IF EXISTS "Public read access for videos" ON storage.objects;
