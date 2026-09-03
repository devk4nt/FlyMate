-- v1.7 업데이트 공지 발송 — 초대 링크 공유 (문의 반영)
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ v1.7 출시 확인 후 실행 (2026-09-03 출시 완료)
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.7-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  '442143a6-a168-47e2-bc4b-ffbcc819432d',
  '🔗 v1.7 업데이트 — 초대 링크로 스터디원을 초대해요',
  E'FlyMate 1.7 업데이트 소식이에요 ✈️\n\n초대 코드를 일일이 알려주기 번거로우셨죠? 이제 링크 하나로 초대할 수 있어요.\n\n[새로워진 내용]\n• 스터디 화면의 [초대 링크 공유] 버튼으로 카카오톡·문자에 초대 메시지 보내기\n• 초대받은 분이 링크를 탭하면 가입 신청 화면으로 바로 이동\n• 앱이 없는 분에게는 설치 안내까지 자동으로\n\n공유 메시지에는 초대 코드도 함께 담겨요. 코드를 직접 입력해 참여하는 방법도 그대로예요.\n스터디를 만든 분이 승인하는 절차도 그대로 유지됩니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n더 편하게, FlyMate ✈️',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '🔗 v1.7 업데이트 — 초대 링크로 스터디원을 초대해요',
  '카카오톡·문자로 초대 링크를 보내면 바로 가입 신청할 수 있어요. App Store에서 업데이트해 주세요!',
  '442143a6-a168-47e2-bc4b-ffbcc819432d'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.7 업데이트 소식이에요 ✈️\n\n초대 코드를 일일이 알려주기 번거로우셨죠? 이제 링크 하나로 초대할 수 있어요.\n\n[새로워진 내용]\n• 스터디 화면의 [초대 링크 공유] 버튼으로 카카오톡·문자에 초대 메시지 보내기\n• 초대받은 분이 링크를 탭하면 가입 신청 화면으로 바로 이동\n• 앱이 없는 분에게는 설치 안내까지 자동으로\n\n공유 메시지에는 초대 코드도 함께 담겨요. 코드를 직접 입력해 참여하는 방법도 그대로예요.\n스터디를 만든 분이 승인하는 절차도 그대로 유지됩니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n더 편하게, FlyMate ✈️'
WHERE reference_announcement_id = '442143a6-a168-47e2-bc4b-ffbcc819432d';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = '442143a6-a168-47e2-bc4b-ffbcc819432d';
