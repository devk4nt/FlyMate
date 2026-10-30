-- v1.6 업데이트 공지 발송 (2026-09-01) — 문구 사용자 확정본 (v1.5 스타일, FlyMate 표기)
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.6-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  'a2d0526d-684d-4a9f-88c3-fece1684e74a',
  '🛠️ v1.6 업데이트 — 불편했던 문제들을 수정했어요',
  E'FlyMate 1.6 업데이트 소식이에요 ✈️\n\n문의해 주신 덕분에 발견된 문제들을 수정했어요.\n\n[수정된 내용]\n• 프로필 사진을 변경해도 화면에 바로 반영되지 않던 문제\n• 공지사항 저장이 실패해도 안내되지 않던 문제\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n이용에 불편을 드려 죄송합니다. 소중한 의견 주셔서 감사합니다.\n더 안정적으로, FlyMate ✈️',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '🛠️ v1.6 업데이트 — 불편했던 문제들을 수정했어요',
  '프로필 사진 변경·공지사항 저장 문제를 수정했어요. App Store에서 업데이트해 주세요!',
  'a2d0526d-684d-4a9f-88c3-fece1684e74a'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.6 업데이트 소식이에요 ✈️\n\n문의해 주신 덕분에 발견된 문제들을 수정했어요.\n\n[수정된 내용]\n• 프로필 사진을 변경해도 화면에 바로 반영되지 않던 문제\n• 공지사항 저장이 실패해도 안내되지 않던 문제\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n이용에 불편을 드려 죄송합니다. 소중한 의견 주셔서 감사합니다.\n더 안정적으로, FlyMate ✈️'
WHERE reference_announcement_id = 'a2d0526d-684d-4a9f-88c3-fece1684e74a';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = 'a2d0526d-684d-4a9f-88c3-fece1684e74a';
