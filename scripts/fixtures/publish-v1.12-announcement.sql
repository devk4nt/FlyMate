-- v1.12 업데이트 공지 발송 — 빠른 피드백 요청 알림 + 피드백 확인 표시
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ v1.12는 2026-10-13 출시 완료(READY_FOR_SALE) 확인됨
-- ⚠️ 서버 변경 없음 — 마이그레이션 4건(20261003/20261004/20261005/20261011)은 이미 prod 적용 완료
-- ⚠️ 재실행 금지 — ②는 ON CONFLICT로 막히지만 ③이 popup_shown_at을 다시 NULL로 돌려 팝업이 재노출된다
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.12-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  '1b79f3eb-2ae4-47bb-a2e3-640e38c13a5b',
  '🔔 v1.12 업데이트 — 새 요청을 알림으로 알려드려요',
  E'FlyMate 1.12 업데이트 소식이에요 ✈️\n\n빠른 피드백은 먼저 봐주는 사람이 있어야 굴러가요. 그런데 요청이 올라온 걸 모르면 지나치게 되죠. 이제 알림으로 알려드려요.\n\n[새로워진 내용]\n• 새 빠른 피드백 요청이 올라오면 알림이 가요\n• 알림을 누르면 바로 그 화면으로 이동해요 — 1분이면 충분해요\n• 알림이 부담되지 않도록 하루 한 번까지만 보내드려요\n\n[피드백에 고마움을 전해보세요]\n• 내 영상에 달린 피드백에 "확인" 표시를 할 수 있어요\n• 답글을 쓰지 않아도 표시만으로 작성자에게 알림이 가요\n• 확인한 피드백은 다른 분들에게도 표시돼요\n\n봐주신 분께 건네는 작은 인사가 다음 피드백을 부릅니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '🔔 v1.12 업데이트 — 새 요청을 알림으로 알려드려요',
  '빠른 피드백 요청이 올라오면 알림으로 알려드려요. App Store에서 업데이트해 주세요!',
  '1b79f3eb-2ae4-47bb-a2e3-640e38c13a5b'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.12 업데이트 소식이에요 ✈️\n\n빠른 피드백은 먼저 봐주는 사람이 있어야 굴러가요. 그런데 요청이 올라온 걸 모르면 지나치게 되죠. 이제 알림으로 알려드려요.\n\n[새로워진 내용]\n• 새 빠른 피드백 요청이 올라오면 알림이 가요\n• 알림을 누르면 바로 그 화면으로 이동해요 — 1분이면 충분해요\n• 알림이 부담되지 않도록 하루 한 번까지만 보내드려요\n\n[피드백에 고마움을 전해보세요]\n• 내 영상에 달린 피드백에 "확인" 표시를 할 수 있어요\n• 답글을 쓰지 않아도 표시만으로 작성자에게 알림이 가요\n• 확인한 피드백은 다른 분들에게도 표시돼요\n\n봐주신 분께 건네는 작은 인사가 다음 피드백을 부릅니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.',
    popup_shown_at = NULL
WHERE reference_announcement_id = '1b79f3eb-2ae4-47bb-a2e3-640e38c13a5b';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = '1b79f3eb-2ae4-47bb-a2e3-640e38c13a5b';
