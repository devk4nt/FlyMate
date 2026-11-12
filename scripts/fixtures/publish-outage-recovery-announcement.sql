-- 서버 장애 복구 공지 발송 — 10/16(금) Cached Egress 쿼터 초과로 인한 접속 오류 안내 및 정상화
-- 절차: ①게시(전문) ②전 유저 요약 INSERT → INSERT 웹훅이 푸시 발송 ③즉시 전문 UPDATE(팝업·알림함용)
-- ⚠️ ②는 ①의 created_at 기준 5분 내 실행돼야 푸시가 나감 (백필 스킵 로직) — 한 파일에서 함께 실행되므로 문제없음
-- ⚠️ 재실행 금지 — ②는 ON CONFLICT로 막히지만 ③이 popup_shown_at을 다시 NULL로 돌려 팝업이 재노출된다
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/publish-outage-recovery-announcement.sql

-- ① 공지 게시 (전문)
INSERT INTO announcements (id, title, body, is_published)
VALUES (
  'cb1523d7-0e2e-4414-b206-0729f064d608',
  '일시적인 서비스 접속 오류 안내 및 정상화 공지',
  E'FlyMate를 이용해 주시는 모든 분들께 불편을 드려 죄송합니다.\n\n10월 16일(금) 낮부터 저녁 사이, 일부 시간대에 영상과 피드백이 정상적으로 불러와지지 않는 오류가 발생했습니다. 해당 시간대에 접속이 되지 않거나 화면이 멈춘 것처럼 보이셨다면 저희 측 서버 오류가 있었습니다.\n\n현재는 완전히 정상화되었음을 안내드립니다. 이용에 불편을 겪으신 점 다시 한번 사과드리며, 추가로 불편한 사항이 있으시면 설정 > 문의하기를 통해 말씀해 주시기 바랍니다.\n\n더 안정적인 서비스를 제공할 수 있도록 노력하겠습니다. 기다려 주셔서 감사합니다.',
  true
);

-- ② 전 유저 알림 INSERT — body는 푸시용 짧은 요약 (INSERT 웹훅 → FCM 발송)
INSERT INTO notifications (recipient_id, type, title, body, reference_announcement_id)
SELECT u.id, 'announcement', '일시적인 서비스 접속 오류 안내 및 정상화 공지',
  '지난 금요일 한때 영상·피드백 조회에 오류가 있었습니다. 현재는 정상적으로 이용 가능합니다.',
  'cb1523d7-0e2e-4414-b206-0729f064d608'
FROM users u
ON CONFLICT (recipient_id, reference_announcement_id)
  WHERE reference_announcement_id IS NOT NULL
  DO NOTHING;

-- ③ 같은 행들을 공지 전문으로 UPDATE (UPDATE는 웹훅 미발동 → 푸시 중복 없음, 팝업·알림함은 전문 표시)
UPDATE notifications
SET body = E'FlyMate를 이용해 주시는 모든 분들께 불편을 드려 죄송합니다.\n\n10월 16일(금) 낮부터 저녁 사이, 일부 시간대에 영상과 피드백이 정상적으로 불러와지지 않는 오류가 발생했습니다. 해당 시간대에 접속이 되지 않거나 화면이 멈춘 것처럼 보이셨다면 저희 측 서버 오류가 있었습니다.\n\n현재는 완전히 정상화되었음을 안내드립니다. 이용에 불편을 겪으신 점 다시 한번 사과드리며, 추가로 불편한 사항이 있으시면 설정 > 문의하기를 통해 말씀해 주시기 바랍니다.\n\n더 안정적인 서비스를 제공할 수 있도록 노력하겠습니다. 기다려 주셔서 감사합니다.',
    popup_shown_at = NULL
WHERE reference_announcement_id = 'cb1523d7-0e2e-4414-b206-0729f064d608';

SELECT count(*) AS notified_users FROM notifications
WHERE reference_announcement_id = 'cb1523d7-0e2e-4414-b206-0729f064d608';
