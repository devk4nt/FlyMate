-- 모집 글 작성자 프로필 이미지와 공개 활동 통계 조회 지원

ALTER TABLE recruit_posts
ADD COLUMN IF NOT EXISTS author_profile_url TEXT;

UPDATE recruit_posts rp
SET author_name = u.name,
    author_profile_url = u.profile_image_url
FROM users u
WHERE u.id = rp.author_id;

CREATE OR REPLACE FUNCTION hydrate_recruit_post_author_profile()
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

DROP TRIGGER IF EXISTS hydrate_recruit_post_author_profile_trigger ON recruit_posts;
CREATE TRIGGER hydrate_recruit_post_author_profile_trigger
    BEFORE INSERT ON recruit_posts
    FOR EACH ROW
    EXECUTE FUNCTION hydrate_recruit_post_author_profile();

CREATE OR REPLACE FUNCTION sync_recruit_post_author_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE recruit_posts
    SET author_name = NEW.name,
        author_profile_url = NEW.profile_image_url
    WHERE author_id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_recruit_post_author_profile_trigger ON users;
CREATE TRIGGER sync_recruit_post_author_profile_trigger
    AFTER UPDATE OF name, profile_image_url ON users
    FOR EACH ROW
    WHEN (
        OLD.name IS DISTINCT FROM NEW.name
        OR OLD.profile_image_url IS DISTINCT FROM NEW.profile_image_url
    )
    EXECUTE FUNCTION sync_recruit_post_author_profile();

CREATE OR REPLACE FUNCTION get_user_activity_stats(p_user_id UUID)
RETURNS TABLE(
    studies_count INT,
    videos_uploaded_count INT,
    feedback_received_count INT,
    feedback_given_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'USER_NOT_FOUND';
    END IF;

    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::INT FROM study_members sm
         WHERE sm.user_id = p_user_id),
        (SELECT COUNT(*)::INT FROM videos v
         WHERE v.uploader_id = p_user_id),
        (SELECT COUNT(*)::INT FROM feedbacks f
         JOIN videos v ON v.id = f.video_id
         WHERE v.uploader_id = p_user_id
           AND f.author_id <> p_user_id),
        (SELECT COUNT(*)::INT FROM feedbacks f
         WHERE f.author_id = p_user_id);
END;
$$;
