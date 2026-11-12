-- 모집글 댓글 → 알림. recruit_comments 는 알림 트리거가 없는 유일한 상호작용
-- 테이블이었다. 실제로 11/05 신규 가입자가 남긴 "참여하고싶습니다" 댓글이
-- 아무에게도 닿지 않았고 그 유저는 다시 돌아오지 않았다.
--
-- 타입은 기존 'recruit_post' 를 재사용한다 — 배포된 앱(1.14)이 이미 이 타입을
-- 모집글 상세로 딥링크하므로 앱 릴리스 없이 즉시 동작한다.

CREATE OR REPLACE FUNCTION notify_recruit_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_post       recruit_posts;
    v_parent_author UUID;
    v_snippet    TEXT;
BEGIN
    SELECT * INTO v_post FROM recruit_posts WHERE id = NEW.post_id;
    IF v_post.id IS NULL OR v_post.is_hidden THEN
        RETURN NEW;
    END IF;

    v_snippet := left(regexp_replace(NEW.content, '\s+', ' ', 'g'), 40);

    -- 1) 답글이면 원 댓글 작성자에게 (참여 문의자가 방장 답을 받았다는 걸 알아야 돌아온다)
    IF NEW.parent_id IS NOT NULL THEN
        SELECT author_id INTO v_parent_author FROM recruit_comments WHERE id = NEW.parent_id;

        INSERT INTO notifications (recipient_id, type, title, body, reference_recruit_post_id)
        SELECT v_parent_author, 'recruit_post', '내 댓글에 답글',
               format('%s님: %s', NEW.author_name, v_snippet), v_post.id
        WHERE v_parent_author IS NOT NULL
          AND v_parent_author <> NEW.author_id
          AND NOT EXISTS (
                SELECT 1 FROM blocked_users b
                WHERE b.blocker_id = v_parent_author AND b.blocked_id = NEW.author_id);
    END IF;

    -- 2) 모집글 작성자에게 (답글 대상과 같은 사람이면 위에서 이미 보냈으므로 제외)
    INSERT INTO notifications (recipient_id, type, title, body, reference_recruit_post_id)
    SELECT v_post.author_id, 'recruit_post', '내 모집글에 댓글',
           format('%s님: %s', NEW.author_name, v_snippet), v_post.id
    WHERE v_post.author_id <> NEW.author_id
      AND v_post.author_id IS DISTINCT FROM v_parent_author
      AND NOT EXISTS (
            SELECT 1 FROM blocked_users b
            WHERE b.blocker_id = v_post.author_id AND b.blocked_id = NEW.author_id);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_recruit_comment ON recruit_comments;
CREATE TRIGGER trg_notify_recruit_comment
    AFTER INSERT ON recruit_comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_recruit_comment();

NOTIFY pgrst, 'reload schema';
