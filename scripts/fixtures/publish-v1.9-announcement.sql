-- v1.9 업데이트 공지 발송 — 모집 글에서 바로 가입 신청
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ v1.9 출시 확인 후 실행 (2026-09-09 READY_FOR_SALE 확인)
-- ⚠️ 서버 RPC request_join_study_by_post 가 prod에 적용돼 있어야 함 (20260906000000, 적용 완료)
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.9-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  '885e2876-f351-4e81-bbc9-d7e98a50038d',
  '🙌 v1.9 업데이트 — 모집 글에서 바로 가입 신청',
  E'FlyMate 1.9 업데이트 소식이에요 ✈️\n\n마음에 드는 스터디를 찾아도 초대 코드를 받기까지 기다려야 했죠? 이제 모집 글에서 바로 신청할 수 있어요.\n\n[새로워진 내용]\n• 모집 글에 [가입 신청] 버튼이 생겼어요\n• 초대 코드 없이 눌러서 바로 신청\n• 신청이 오면 스터디를 만든 분에게 알림이 가고, 승인하면 참여 완료\n\n[스터디를 운영 중이시라면]\n모집 글을 올려두면 자리가 남은 스터디에 바로 신청이 들어와요. 모집 탭 오른쪽 위 글쓰기 버튼으로 올릴 수 있어요.\n\n초대 코드로 참여하는 방법도 그대로예요.\n스터디를 만든 분이 승인하는 절차도 그대로 유지됩니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n함께 연습해요, FlyMate ✈️',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '🙌 v1.9 업데이트 — 모집 글에서 바로 가입 신청',
  '이제 초대 코드 없이 모집 글에서 바로 가입 신청할 수 있어요. App Store에서 업데이트해 주세요!',
  '885e2876-f351-4e81-bbc9-d7e98a50038d'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.9 업데이트 소식이에요 ✈️\n\n마음에 드는 스터디를 찾아도 초대 코드를 받기까지 기다려야 했죠? 이제 모집 글에서 바로 신청할 수 있어요.\n\n[새로워진 내용]\n• 모집 글에 [가입 신청] 버튼이 생겼어요\n• 초대 코드 없이 눌러서 바로 신청\n• 신청이 오면 스터디를 만든 분에게 알림이 가고, 승인하면 참여 완료\n\n[스터디를 운영 중이시라면]\n모집 글을 올려두면 자리가 남은 스터디에 바로 신청이 들어와요. 모집 탭 오른쪽 위 글쓰기 버튼으로 올릴 수 있어요.\n\n초대 코드로 참여하는 방법도 그대로예요.\n스터디를 만든 분이 승인하는 절차도 그대로 유지됩니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n함께 연습해요, FlyMate ✈️',
    popup_shown_at = NULL
WHERE reference_announcement_id = '885e2876-f351-4e81-bbc9-d7e98a50038d';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = '885e2876-f351-4e81-bbc9-d7e98a50038d';
