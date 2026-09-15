-- 멤버는 모였는데 영상이 0개인 스터디의 멤버 전원에게 첫 영상 업로드 넛지
--
-- 배경: 2026-09-15 기준 '영상 면접 스터디'가 이틀 만에 멤버 5명을 모았으나 영상 0개.
-- 멤버 1명짜리 스터디가 6개나 죽어 있는 패턴의 반복 직전이라, 첫 영상이 올라가는지가
-- 스터디 생존의 분기점이다. 방장만이 아니라 멤버 전원에게 보낸다(누가 올리든 물꼬가 트임).
--
-- nudge-smile-practice.sql 과 동일한 방식:
-- announcements 미게시 → 시작 팝업 없음. reference_announcement_id NULL 이라 백필 스킵 로직도 안 탄다.
-- 알림함에는 남고(탭하면 본문 시트), 푸시는 INSERT 웹훅이 발송.
--
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-first-video.sql
--
-- ⚠️ 재실행 금지 — 중복 방지 제약이 없다(ON CONFLICT 대상 없음).
-- ⚠️ 대상은 하드코딩이 아니라 조건으로 뽑는다. 실행 시점에 조건을 만족하는 스터디가
--    늘어나 있을 수 있으므로, 아래 미리보기 SELECT 로 대상을 먼저 확인할 것.

-- ① 대상 미리보기 (먼저 이것만 보고 확인)
SELECT s.name AS study, count(m.user_id) AS members
FROM studies s
JOIN study_members m ON m.study_id = s.id
WHERE NOT EXISTS (SELECT 1 FROM videos v WHERE v.study_id = s.id)
  AND (SELECT count(*) FROM study_members x WHERE x.study_id = s.id) >= 2
GROUP BY s.id, s.name;

-- ② 발송
INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
SELECT m.user_id,
       'announcement',
       '🎬 첫 영상을 기다리고 있어요',
       '스터디원이 모였어요! 누구든 첫 영상을 올리면 서로 피드백을 주고받을 수 있어요. 3분 이내 영상이면 충분해요.',
       s.id
FROM studies s
JOIN study_members m ON m.study_id = s.id
WHERE NOT EXISTS (SELECT 1 FROM videos v WHERE v.study_id = s.id)
  AND (SELECT count(*) FROM study_members x WHERE x.study_id = s.id) >= 2;

SELECT count(*) AS notified FROM notifications
WHERE title = '🎬 첫 영상을 기다리고 있어요';
