-- 전 사용자 대상 영상 업로드 유도 넛지
--
-- 배경: 2026-09-23 기준 3일째 영상 0건 / 피드백 0건. 누적 영상 21건, 업로더 13명.
-- 대상을 둘로 나눈다 — 스터디 없는 44명은 스터디에 영상을 올릴 수 없으므로
-- 같은 문구가 안 먹는다. 이들은 '빠른 피드백'(스터디 없이 영상 업로드)으로 유도.
--
-- nudge-first-video.sql 과 동일한 방식:
-- announcements 미게시 → 시작 팝업 없음. reference_announcement_id NULL 이라 백필 스킵 로직도 안 탄다.
-- 알림함에는 남고, 푸시는 INSERT 웹훅이 발송.
--
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-upload-video.sql
--
-- ⚠️ 재실행 금지 — 중복 방지 제약이 없다(ON CONFLICT 대상 없음).
-- ⚠️ 테스트 계정(eileenyoo1@naver.com) 제외. 사용자당 1건만 발송된다.

-- ① 대상 미리보기 (먼저 이것만 보고 확인)
SELECT CASE WHEN EXISTS(SELECT 1 FROM study_members m WHERE m.user_id = u.id)
            THEN 'A. 스터디 멤버' ELSE 'B. 스터디 없음' END AS segment,
       count(*) AS users,
       count(*) FILTER (WHERE EXISTS(
         SELECT 1 FROM device_tokens d WHERE d.user_id = u.id AND d.notifications_enabled)) AS pushable
FROM users u
WHERE u.email <> 'eileenyoo1@naver.com'
GROUP BY 1;

-- ② 발송 A — 스터디에 속한 사용자: 자기 스터디로 딥링크
INSERT INTO notifications (recipient_id, type, title, body, reference_study_id)
SELECT DISTINCT ON (m.user_id)
       m.user_id,
       'announcement',
       '🎬 오늘 영상 한 편, 올려볼까요?',
       '3분 이내 영상 하나면 충분해요. 올려두면 스터디원들이 표정·시선·말투를 짚어줘요. 먼저 올리는 사람이 피드백도 가장 많이 받아요.',
       m.study_id
FROM study_members m
JOIN users u ON u.id = m.user_id
WHERE u.email <> 'eileenyoo1@naver.com'
ORDER BY m.user_id, m.study_id;

-- ③ 발송 B — 스터디 없는 사용자: 빠른 피드백으로 유도 (딥링크 없음)
INSERT INTO notifications (recipient_id, type, title, body)
SELECT u.id,
       'announcement',
       '🎬 스터디 없이도 영상 피드백을 받을 수 있어요',
       '''빠른 피드백''에 영상을 올리면 스터디에 속하지 않아도 피드백을 받을 수 있어요. 3분 이내 영상 한 편이면 충분해요.'
FROM users u
WHERE u.email <> 'eileenyoo1@naver.com'
  AND NOT EXISTS (SELECT 1 FROM study_members m WHERE m.user_id = u.id);

SELECT title, count(*) AS notified FROM notifications
WHERE title IN ('🎬 오늘 영상 한 편, 올려볼까요?', '🎬 스터디 없이도 영상 피드백을 받을 수 있어요')
GROUP BY title;
