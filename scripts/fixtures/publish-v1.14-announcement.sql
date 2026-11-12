-- v1.14 업데이트 공지 발송 — 주간 마감 리마인더 + 멤버 공지 전문 보기
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ 실행 전 1.14가 READY_FOR_SALE인지 확인할 것 (공지가 "App Store에서 업데이트" 안내를 담고 있음)
-- ⚠️ 마이그레이션 2건(20261019000000/20261020000000)은 2026-10-24 prod 적용 완료
-- ⚠️ 재실행 금지 — ②는 ON CONFLICT로 막히지만 ③이 popup_shown_at을 다시 NULL로 돌려 팝업이 재노출된다
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-v1.14-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  'dfad6d1a-ecf8-41e0-9318-06c2bd116669',
  '🔔 v1.14 업데이트 — 마감 요일을 정하면 알림이 챙겨드려요',
  E'FlyMate 1.14 업데이트 소식이에요 ✈️\n\n스터디가 느슨해지는 건 의욕이 없어서가 아니에요. 그냥 깜빡해서죠. 이번 업데이트가 그걸 챙겨드립니다.\n\n[마감 요일 알림]\n• 방장이 스터디마다 영상·피드백 마감 요일을 정할 수 있어요\n• 마감일 저녁 8시, 아직 올리지 않은 멤버에게만 알림이 가요\n• 이미 올린 분은 울리지 않아요 — 같은 스터디 알림은 하루 한 번까지만요\n\n[공지를 끝까지 읽을 수 있어요]\n• 방장이 올린 공지를 멤버도 전문으로 볼 수 있어요\n• 알림을 눌렀을 때 화면이 로딩에서 멈추던 문제도 고쳤어요\n\n방장이시라면 스터디 상세에서 마감 요일만 정해주세요. 다음 주부터 알림이 알아서 챙깁니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '🔔 v1.14 업데이트 — 마감 요일을 정하면 알림이 챙겨드려요',
  '마감 요일을 정하면 저녁 8시에 아직 안 한 멤버만 챙겨드려요. App Store에서 업데이트해 주세요!',
  'dfad6d1a-ecf8-41e0-9318-06c2bd116669'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate 1.14 업데이트 소식이에요 ✈️\n\n스터디가 느슨해지는 건 의욕이 없어서가 아니에요. 그냥 깜빡해서죠. 이번 업데이트가 그걸 챙겨드립니다.\n\n[마감 요일 알림]\n• 방장이 스터디마다 영상·피드백 마감 요일을 정할 수 있어요\n• 마감일 저녁 8시, 아직 올리지 않은 멤버에게만 알림이 가요\n• 이미 올린 분은 울리지 않아요 — 같은 스터디 알림은 하루 한 번까지만요\n\n[공지를 끝까지 읽을 수 있어요]\n• 방장이 올린 공지를 멤버도 전문으로 볼 수 있어요\n• 알림을 눌렀을 때 화면이 로딩에서 멈추던 문제도 고쳤어요\n\n방장이시라면 스터디 상세에서 마감 요일만 정해주세요. 다음 주부터 알림이 알아서 챙깁니다.\n\nApp Store에서 최신 버전으로 업데이트하시면 바로 적용됩니다.',
    popup_shown_at = NULL
WHERE reference_announcement_id = 'dfad6d1a-ecf8-41e0-9318-06c2bd116669';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = 'dfad6d1a-ecf8-41e0-9318-06c2bd116669';
