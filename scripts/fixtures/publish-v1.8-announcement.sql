-- v1.8 업데이트 공지 발송 (2026-09) — 미소 연습 거울 출시
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ 발송 타이밍: 1.8이 App Store에 READY_FOR_SALE 된 후 실행할 것 (그 전엔 유저가 업데이트 불가)
-- 실행(스테이징): node scripts/apply-migrations.mjs kilkzezzkvyegnuubltg --file scripts/fixtures/publish-v1.8-announcement.sql
-- 실행(프로덕션): node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.8-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  '3d02e959-0ba1-4170-8608-9b5a84c0b626',
  '✨ v1.8 업데이트 — 미소 연습 거울이 생겼어요',
  E'FlyMate 1.8 업데이트 소식이에요 ✈️\n\n영상면접 준비의 핵심, 미소를 이제 FlyMate에서 연습할 수 있어요.\n\n[새로운 기능 — 미소 연습 거울]\n• 전면 카메라로 미소를 실시간 측정해요 (얼굴 데이터는 기기에서만 처리되고 저장되지 않아요)\n• 연습이 끝나면 미소 유지율 그래프 리포트를 보여드려요\n• 리포트를 이미지로 공유해 친구에게 자랑해보세요\n• 1일 1미소 알림으로 매일 연습 루틴을 만들 수 있어요 (설정 > 알림)\n\n스터디 탭 오른쪽 아래 😊 버튼에서 바로 시작할 수 있어요.\nApp Store에서 최신 버전으로 업데이트해 주세요.\n\n오늘도 밝게, FlyMate ✈️',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '✨ v1.8 업데이트 — 미소 연습 거울이 생겼어요',
  '전면 카메라로 미소를 실시간 측정하고 리포트로 확인해보세요. App Store에서 업데이트!',
  '3d02e959-0ba1-4170-8608-9b5a84c0b626'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.8 업데이트 소식이에요 ✈️\n\n영상면접 준비의 핵심, 미소를 이제 FlyMate에서 연습할 수 있어요.\n\n[새로운 기능 — 미소 연습 거울]\n• 전면 카메라로 미소를 실시간 측정해요 (얼굴 데이터는 기기에서만 처리되고 저장되지 않아요)\n• 연습이 끝나면 미소 유지율 그래프 리포트를 보여드려요\n• 리포트를 이미지로 공유해 친구에게 자랑해보세요\n• 1일 1미소 알림으로 매일 연습 루틴을 만들 수 있어요 (설정 > 알림)\n\n스터디 탭 오른쪽 아래 😊 버튼에서 바로 시작할 수 있어요.\nApp Store에서 최신 버전으로 업데이트해 주세요.\n\n오늘도 밝게, FlyMate ✈️'
WHERE reference_announcement_id = '3d02e959-0ba1-4170-8608-9b5a84c0b626';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = '3d02e959-0ba1-4170-8608-9b5a84c0b626';
