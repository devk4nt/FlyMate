select name, owner, owner_id, created_at, updated_at
from storage.objects where bucket_id = 'profile-images'
order by updated_at desc limit 5;
