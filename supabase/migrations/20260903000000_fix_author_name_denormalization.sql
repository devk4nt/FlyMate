-- ============================================================
-- 비정규화 작성자 이름 저장 오류 수정
--
-- 문제 1 (쓰기): feedback_comments / recruit_comments 는 클라이언트가
--   auth userMetadata["name"] ?? "" 를 그대로 보낸다. Apple 프라이빗 릴레이처럼
--   metadata에 name이 없는 계정은 빈 문자열이 저장돼 앱에서 작성자가 안 보인다.
--   feedbacks / videos / recruit_posts 는 BEFORE INSERT 트리거로 public.users 에서
--   채우기 때문에 정상 — 같은 방식으로 통일한다.
--
-- 문제 2 (변경 전파): 프로필 이름/사진 변경이 recruit_posts, quick_feedback 사본에만
--   전파돼 study_members / videos / feedbacks / feedback_comments 는 옛 이름이 남았다.
-- ============================================================

-- 1. 작성자 프로필 하이드레이션을 (author_id, author_name, author_profile_url)
--    스키마를 공유하는 테이블 공용 함수로 일반화
DROP TRIGGER IF EXISTS hydrate_recruit_post_author_profile_trigger ON recruit_posts;
DROP FUNCTION IF EXISTS hydrate_recruit_post_author_profile();

CREATE OR REPLACE FUNCTION hydrate_author_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    SELECT u.name, u.profile_image_url
    INTO NEW.author_name, NEW.author_profile_url
    FROM users u
    WHERE u.id = NEW.author_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hydrate_author_profile_trigger ON recruit_posts;
CREATE TRIGGER hydrate_author_profile_trigger
    BEFORE INSERT ON recruit_posts
    FOR EACH ROW EXECUTE FUNCTION hydrate_author_profile();

DROP TRIGGER IF EXISTS hydrate_author_profile_trigger ON recruit_comments;
CREATE TRIGGER hydrate_author_profile_trigger
    BEFORE INSERT ON recruit_comments
    FOR EACH ROW EXECUTE FUNCTION hydrate_author_profile();

DROP TRIGGER IF EXISTS hydrate_author_profile_trigger ON feedback_comments;
CREATE TRIGGER hydrate_author_profile_trigger
    BEFORE INSERT ON feedback_comments
    FOR EACH ROW EXECUTE FUNCTION hydrate_author_profile();

-- 2. 프로필 변경 전파를 모든 사본으로 확장 (recruit_posts 전용 → 공용)
DROP TRIGGER IF EXISTS sync_recruit_post_author_profile_trigger ON users;
DROP FUNCTION IF EXISTS sync_recruit_post_author_profile();

CREATE OR REPLACE FUNCTION sync_user_profile_copies()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE recruit_posts
       SET author_name = NEW.name, author_profile_url = NEW.profile_image_url
     WHERE author_id = NEW.id;

    UPDATE recruit_comments
       SET author_name = NEW.name, author_profile_url = NEW.profile_image_url
     WHERE author_id = NEW.id;

    UPDATE feedback_comments
       SET author_name = NEW.name, author_profile_url = NEW.profile_image_url
     WHERE author_id = NEW.id;

    UPDATE feedbacks
       SET author_name = NEW.name, author_profile_url = NEW.profile_image_url
     WHERE author_id = NEW.id;

    UPDATE videos
       SET uploader_name = NEW.name
     WHERE uploader_id = NEW.id;

    UPDATE study_members
       SET user_name = NEW.name, profile_image_url = NEW.profile_image_url
     WHERE user_id = NEW.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_user_profile_copies_trigger ON users;
CREATE TRIGGER sync_user_profile_copies_trigger
    AFTER UPDATE OF name, profile_image_url ON users
    FOR EACH ROW
    WHEN (OLD.name IS DISTINCT FROM NEW.name
       OR OLD.profile_image_url IS DISTINCT FROM NEW.profile_image_url)
    EXECUTE FUNCTION sync_user_profile_copies();

-- 3. 기존 잘못 저장된 행 백필 (빈 이름 + 변경 미전파 모두)
UPDATE feedback_comments c SET author_name = u.name, author_profile_url = u.profile_image_url
  FROM users u WHERE u.id = c.author_id AND c.author_name IS DISTINCT FROM u.name;

UPDATE recruit_comments rc SET author_name = u.name, author_profile_url = u.profile_image_url
  FROM users u WHERE u.id = rc.author_id AND rc.author_name IS DISTINCT FROM u.name;

UPDATE recruit_posts rp SET author_name = u.name, author_profile_url = u.profile_image_url
  FROM users u WHERE u.id = rp.author_id AND rp.author_name IS DISTINCT FROM u.name;

UPDATE feedbacks f SET author_name = u.name, author_profile_url = u.profile_image_url
  FROM users u WHERE u.id = f.author_id AND f.author_name IS DISTINCT FROM u.name;

UPDATE videos v SET uploader_name = u.name
  FROM users u WHERE u.id = v.uploader_id AND v.uploader_name IS DISTINCT FROM u.name;

UPDATE study_members m SET user_name = u.name, profile_image_url = u.profile_image_url
  FROM users u WHERE u.id = m.user_id AND m.user_name IS DISTINCT FROM u.name;
