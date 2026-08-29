-- 대시보드에서만 수정되어 마이그레이션에 없던 RLS 정책 회수 (2026-08-29 staging 가입신청 조회 42P17로 발견)
--
-- supabase_schema.sql 스냅샷의 "Members can read study members" 정책은
-- study_members가 자기 자신을 서브쿼리로 참조해 무한 재귀(42P17)를 일으킨다.
-- prod는 대시보드에서 SECURITY DEFINER 헬퍼 is_study_member()로 교체해 해결했지만
-- (함수는 20260829010000에서 회수) 정책 자체는 회수되지 않아 새 환경(staging)이 깨진 채 부트스트랩됐다.
--
-- prod에는 이미 동일 정책이 존재 — 히스토리만 등록(--mark). staging에서는 실제 실행.

DROP POLICY IF EXISTS "Members can read studies" ON studies;
CREATE POLICY "Members can read studies"
    ON studies FOR SELECT
    USING (is_study_member(id));

DROP POLICY IF EXISTS "Members can read study members" ON study_members;
CREATE POLICY "Members can read study members"
    ON study_members FOR SELECT
    USING (user_id = auth.uid() OR is_study_member(study_id));
