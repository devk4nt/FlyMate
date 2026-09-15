-- v1.10 업데이트 공지 발송 — 스터디 생성 직후 모집 글 작성 유도
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ v1.10 출시(READY_FOR_SALE) 확인 후 실행
-- ⚠️ 서버 변경 없음 — 이번 릴리스는 클라 전용(모집 글 유도 + 마감일 가드).
--    마감일 서버 가드(20260909000000)는 이미 prod 적용 완료
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.10-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  'e3773efb-a00e-4783-b214-d626265c2778',
  '📣 v1.10 업데이트 — 스터디 만들고 모집 글까지 한 번에',
  E'FlyMate 1.10 업데이트 소식이에요 ✈️\n\n스터디를 만들어도 함께할 분을 어떻게 모을지 막막했죠? 이제 개설을 마치면 모집 글 작성까지 바로 이어져요.\n\n[새로워진 내용]\n• 스터디를 만들면 모집 글 작성을 안내해 드려요\n• 스터디 이름·소개는 미리 채워져 있어요 — 일정과 모집 조건만 더하면 끝\n• 올린 글은 모집 탭에 노출되고, 글에서 바로 가입 신청이 들어와요\n\n[이런 점도 고쳤어요]\n• 모집 마감일이 지난 글에서는 가입 신청 버튼이 보이지 않도록 정리했어요\n\n모집 글은 나중에 모집 탭에서도 언제든 올릴 수 있어요.\n초대 링크·초대 코드로 참여하는 방법도 그대로예요.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n함께 연습해요, FlyMate ✈️',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '📣 v1.10 업데이트 — 스터디 만들고 모집 글까지 한 번에',
  '스터디를 만들면 모집 글 작성까지 바로 이어져요. App Store에서 업데이트해 주세요!',
  'e3773efb-a00e-4783-b214-d626265c2778'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.10 업데이트 소식이에요 ✈️\n\n스터디를 만들어도 함께할 분을 어떻게 모을지 막막했죠? 이제 개설을 마치면 모집 글 작성까지 바로 이어져요.\n\n[새로워진 내용]\n• 스터디를 만들면 모집 글 작성을 안내해 드려요\n• 스터디 이름·소개는 미리 채워져 있어요 — 일정과 모집 조건만 더하면 끝\n• 올린 글은 모집 탭에 노출되고, 글에서 바로 가입 신청이 들어와요\n\n[이런 점도 고쳤어요]\n• 모집 마감일이 지난 글에서는 가입 신청 버튼이 보이지 않도록 정리했어요\n\n모집 글은 나중에 모집 탭에서도 언제든 올릴 수 있어요.\n초대 링크·초대 코드로 참여하는 방법도 그대로예요.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.\n\n함께 연습해요, FlyMate ✈️',
    popup_shown_at = NULL
WHERE reference_announcement_id = 'e3773efb-a00e-4783-b214-d626265c2778';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = 'e3773efb-a00e-4783-b214-d626265c2778';
