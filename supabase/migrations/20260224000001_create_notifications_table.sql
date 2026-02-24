-- Migration: notifications 테이블 생성

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('feedback_on_my_video', 'mentioned_in_feedback')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    reference_video_id UUID REFERENCES videos(id) ON DELETE CASCADE,
    reference_feedback_id UUID REFERENCES feedbacks(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_notifications_recipient_id ON notifications(recipient_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications(recipient_id) WHERE is_read = false;

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own notifications"
    ON notifications FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
