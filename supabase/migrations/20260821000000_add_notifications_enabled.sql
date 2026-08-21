-- 기기별 iOS 알림 권한 상태. 토큰 등록(앱 실행) 시마다 갱신되며,
-- send-push-notification 엣지 함수는 false인 토큰에 발송하지 않는다.
ALTER TABLE device_tokens
    ADD COLUMN notifications_enabled BOOLEAN NOT NULL DEFAULT true;

-- Settings 알림 토글이 저장하는 컬럼 — 앱은 이미 update하고 있었으나 컬럼이 없어 실패하던 것 수정.
ALTER TABLE users
    ADD COLUMN notifications_enabled BOOLEAN NOT NULL DEFAULT true;
