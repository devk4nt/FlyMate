-- 스터디별 피드백 현황 확인 (Dashboard SQL Editor에서 실행 — RLS 우회됨)

-- 1. 스터디 목록 + 최근 활동 (여기서 study_id 확보)
select s.id, s.name, count(distinct v.id) as videos, count(f.id) as feedbacks,
       max(f.created_at) as last_feedback
from studies s
left join videos v on v.study_id = s.id
left join feedbacks f on f.study_id = s.id
group by s.id, s.name
order by last_feedback desc nulls last;

-- 2. 특정 스터디에서 오간 피드백 (영상 + 작성자 + 댓글수)
select v.title as video, v.uploader_name as uploader,
       f.author_name, f.timestamp_seconds, f.content,
       f.comment_count, f.created_at
from feedbacks f
join videos v on v.id = f.video_id
where f.study_id = '<STUDY_ID>'
order by f.created_at desc
limit 100;

-- 3. 피드백에 달린 댓글까지 스레드로
select f.content as feedback, f.author_name as feedback_author,
       c.author_name as comment_author, c.content as comment, c.created_at
from feedback_comments c
join feedbacks f on f.id = c.feedback_id
where c.study_id = '<STUDY_ID>'
order by f.created_at, c.created_at;
