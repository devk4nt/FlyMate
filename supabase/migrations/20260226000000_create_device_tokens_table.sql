-- Device tokens for FCM push notifications
CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own device tokens"
    ON device_tokens FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device tokens"
    ON device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device tokens"
    ON device_tokens FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own device tokens"
    ON device_tokens FOR DELETE USING (auth.uid() = user_id);
