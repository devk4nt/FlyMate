-- 스터디 없는 사용자 대상 '빠른 피드백' 영상 업로드 유도 넛지 (버전 공지 아님)
--
-- 배경: 2026-10-07 기준 스터디 미보유 51명 / 푸시 수신 가능 33명.
-- 2026-09-23 nudge-upload-video.sql 의 세그먼트 B 후속 — 같은 대상, 다른 각도(혼자 연습의 한계).
--
-- announcements 미게시 → 시작 팝업 없음. reference_announcement_id NULL 이라 백필 스킵 로직도 안 탄다.
-- 알림함에는 남고(탭하면 본문 시트), 푸시는 INSERT 웹훅이 발송. 딥링크 없음.
--
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-quick-feedback-upload.sql
--
-- 테스트 계정(eileenyoo1@naver.com) 제외. 동일 title 기존 알림이 있으면 건너뛰므로 재실행 안전.

INSERT INTO notifications (recipient_id, type, title, body)
SELECT u.id,
       'announcement',
       $$🎬 혼자 보는 연습 영상, 아깝지 않아요?$$,
       $$스터디에 들어가지 않아도 '빠른 피드백'에 올리면 제3자의 시선으로 피드백을 받을 수 있어요.$$
FROM users u
WHERE u.email <> 'eileenyoo1@naver.com'
  AND NOT EXISTS (SELECT 1 FROM study_members m WHERE m.user_id = u.id)
  AND NOT EXISTS (SELECT 1 FROM notifications n
                  WHERE n.recipient_id = u.id
                    AND n.title = $$🎬 혼자 보는 연습 영상, 아깝지 않아요?$$);

SELECT count(*) AS notified FROM notifications
WHERE title = $$🎬 혼자 보는 연습 영상, 아깝지 않아요?$$;
