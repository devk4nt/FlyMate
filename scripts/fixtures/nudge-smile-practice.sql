-- 미소 연습 권유 넛지 푸시 (버전 공지 아님)
-- announcements 미게시 → 시작 팝업 없음. reference_announcement_id NULL 이라 백필 스킵 로직도 안 탄다.
-- 알림함에는 남고(탭하면 본문 시트), 푸시는 INSERT 웹훅이 발송.
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-smile-practice.sql
--
-- ⚠️ 재실행 금지 — 중복 방지 제약이 없다(ON CONFLICT 대상 없음).

INSERT INTO notifications (recipient_id, type, title, body)
SELECT u.id,
       'announcement',
       '😊 오늘 1분만, 미소 연습 어때요?',
       '자연스러운 미소도 연습이 필요해요. App Store에서 최신 버전으로 업데이트하시면 홈 화면 😊 버튼으로 바로 시작할 수 있어요.'
FROM users u;

SELECT count(*) AS notified FROM notifications
WHERE title = '😊 오늘 1분만, 미소 연습 어때요?';
