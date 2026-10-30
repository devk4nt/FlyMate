select column_name from information_schema.columns
where table_name = 'studies' and column_name in ('notice', 'notice_updated_at');
