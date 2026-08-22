-- 방장 탈퇴 시 유령 스터디 방지
--
-- 배경: 앱의 '스터디 탈퇴'(study_members 직접 DELETE)가 방장을 막지 않아,
-- 방장이 탈퇴하면 studies row가 owner_id를 가진 채 고아로 남았다.
-- 고아 스터디는 목록(study_members 기준)과 RLS SELECT(is_study_member)에서
-- 보이지 않지만 create_study_with_limits의 owner COUNT에는 잡혀
-- 스터디 생성이 영구 차단됐다. (2026-08-22 고아 스터디 2건 수동 정리 완료)
--
-- 동작:
--   1) 방장이 혼자 남은 스터디에서 탈퇴 → 스터디 자체를 삭제 (탈퇴 = 삭제)
--   2) 방장이 다른 멤버가 있는 스터디에서 탈퇴 → 거부 (위임 필요)
--   3) 일반 멤버 탈퇴 / 스터디 삭제 cascade → 기존과 동일
--
-- SECURITY DEFINER 필수: AFTER DELETE 시점에는 탈퇴자의 멤버십이 이미 없어
-- RLS(is_study_member) 하에서는 studies 조회가 빈 결과가 되기 때문.

CREATE OR REPLACE FUNCTION handle_study_member_deleted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_owner_id UUID;
    v_remaining INT;
BEGIN
    SELECT owner_id INTO v_owner_id FROM studies WHERE id = OLD.study_id;

    -- 스터디가 이미 삭제됐거나(cascade 경로) 일반 멤버 탈퇴면 통과
    IF v_owner_id IS NULL OR v_owner_id != OLD.user_id THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*) INTO v_remaining FROM study_members WHERE study_id = OLD.study_id;

    IF v_remaining > 0 THEN
        RAISE EXCEPTION 'OWNER_MUST_TRANSFER_BEFORE_LEAVE';
    END IF;

    -- 혼자 남은 방장의 탈퇴 = 스터디 삭제 (고아 row 방지)
    DELETE FROM studies WHERE id = OLD.study_id;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_study_member_deleted ON study_members;
CREATE TRIGGER on_study_member_deleted
    AFTER DELETE ON study_members
    FOR EACH ROW
    EXECUTE FUNCTION handle_study_member_deleted();
