-- ============================================================
-- Enforce case-insensitive unique nicknames (users.name)
-- ============================================================

-- 1. Dedupe existing rows: append row number to later duplicates
-- ponytail: suffix could theoretically collide with another existing name;
-- if so the index creation below fails and the row needs a manual rename.
WITH dupes AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(name) ORDER BY created_at, id) AS rn
    FROM users
)
UPDATE users u
SET name = u.name || d.rn::TEXT
FROM dupes d
WHERE u.id = d.id AND d.rn > 1;

-- 2. Unique index (case-insensitive)
CREATE UNIQUE INDEX IF NOT EXISTS users_name_lower_key ON users (lower(name));

-- 3. Signup trigger: social providers can hand us duplicate names,
--    so pick "이름", "이름2", "이름3", ... until free
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    base_name TEXT;
    candidate TEXT;
    n INT := 1;
BEGIN
    base_name := COALESCE(
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'full_name',
        'User'
    );
    candidate := base_name;
    WHILE EXISTS (SELECT 1 FROM public.users WHERE lower(name) = lower(candidate)) LOOP
        n := n + 1;
        candidate := base_name || n::TEXT;
    END LOOP;

    INSERT INTO public.users (id, email, name, provider)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        candidate,
        COALESCE(NEW.raw_app_meta_data->>'provider', 'unknown')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
