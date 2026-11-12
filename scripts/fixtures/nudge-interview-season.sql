-- 영상면접 시즌 넛지 푸시 (버전 공지 아님)
-- announcements 미게시 → 시작 팝업 없음. reference_announcement_id NULL 이라 백필 스킵 로직도 안 탄다.
-- 알림함에는 남고(탭하면 본문 시트), 푸시는 INSERT 웹훅이 발송.
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-interview-season.sql
--
-- ⚠️ 재실행 금지 — 중복 방지 제약이 없다(ON CONFLICT 대상 없음).

INSERT INTO notifications (recipient_id, type, title, body)
SELECT u.id,
       'announcement',
       '🎬 영상면접 시즌, 혼자 연습하고 계신가요?',
       '스터디가 없어도 홈 화면의 ''빠른 피드백''으로 1분 영상만 올리면 다른 준비생이 피드백을 남겨드려요. 거울 앞 연습만으론 내 표정과 목소리가 어떻게 보이는지 알기 어렵잖아요. 오늘 연습한 거, 그대로 올려만 두세요.'
FROM users u;

SELECT count(*) AS notified FROM notifications
WHERE title = '🎬 영상면접 시즌, 혼자 연습하고 계신가요?';
