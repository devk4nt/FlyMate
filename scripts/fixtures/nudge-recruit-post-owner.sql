-- 스터디 방장에게 모집 글 작성을 권유하는 개인 넛지 (2026-09-23)
--
-- 배경: '영상 면접 스터디'가 9/18~20 사흘간 영상 6개·피드백 43개로 활발했으나
-- 9/21부터 전 멤버 활동 0. 같은 기간 신규 가입 4명은 들어와도 갈 곳이 없어 이탈했다
-- (공개된 모집 글 0건 → 모집 탭이 비어 있음).
-- 이예원 님은 스터디 3개(개설 한도)를 운영하며 전부 자리가 남아 있고,
-- 피드백 19개를 작성한 최다 기여자다. 모집 글 1건이면 전 유저 푸시가 나가고
-- 신규 가입자가 가입 신청할 수 있게 된다(v1.9 기능).
--
-- ⚠️ 알림 타입 'announcement' 는 탭해도 화면 이동이 없다 — 본문 시트만 열린다
--    (NotificationListFeature:100 early return). 그래서 경로를 본문에 글로 안내한다.
--    reference_study_id 를 넣어도 딥링크는 동작하지 않으므로 넣지 않는다.
-- ⚠️ announcements 에 게시하지 않으므로 시작 팝업 없음. 알림함 + 푸시로만 전달.
-- ⚠️ 재실행 금지 — 중복 방지 제약 없음.
--
-- 실행: node scripts/apply-migrations.mjs fvhrydkofctahxwyvsnp --file scripts/fixtures/nudge-recruit-post-owner.sql

INSERT INTO notifications (recipient_id, type, title, body)
SELECT p.id,
       'announcement',
       '🌿 이예원 님, 스터디에 자리가 조금 남았어요',
       E'이예원 님, 지난주 스터디원들 영상에 남겨주신 피드백들 정말 정성스러웠어요 🌿\n\n조명이나 각도, 말투까지 하나하나 짚어주신 덕분에 스터디 분위기가 살아났던 것 같아요.\n\n혹시 함께 연습할 분을 조금 더 만나보고 싶으시다면, 모집 탭에서 모집 글을 올려보시는 건 어떨까요? 지금 운영 중인 스터디들에 자리가 남아 있어서, 글을 올리시면 FlyMate를 쓰는 다른 준비생들에게 소식이 전해져요.\n\n모집 탭 오른쪽 위 글쓰기 버튼으로 올릴 수 있어요.\n\n물론 지금처럼 기존 멤버분들과 이어가셔도 좋아요. 필요해지시면 그때 올려보셔도 늦지 않아요.\n\n함께 연습해요, FlyMate ✈️'
FROM users p
WHERE p.name = '이예원';

SELECT n.recipient_id, p.name, n.title, n.created_at at time zone 'Asia/Seoul' as sent_kst
FROM notifications n JOIN users p ON p.id = n.recipient_id
WHERE n.title = '🌿 이예원 님, 스터디에 자리가 조금 남았어요';
