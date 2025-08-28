-- BarkDate Storage Buckets & RLS Policies
-- Run this in Supabase SQL editor once. It creates buckets (if missing) and adds policies.

-- 1) Create buckets (idempotent)
select storage.create_bucket('user-avatars', public := true);
select storage.create_bucket('dog-photos', public := true);
select storage.create_bucket('post-images', public := true);
select storage.create_bucket('chat-media', public := false);
select storage.create_bucket('playdate-albums', public := true);

-- 2) USER AVATARS (public reads, owner writes)
create policy if not exists "Users can upload own avatars"
on storage.objects for insert
with check (
  bucket_id = 'user-avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Anyone can view avatars"
on storage.objects for select
using (bucket_id = 'user-avatars');

create policy if not exists "Users can update own avatars"
on storage.objects for update
using (
  bucket_id = 'user-avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Users can delete own avatars"
on storage.objects for delete
using (
  bucket_id = 'user-avatars'
  and auth.uid()::text = (storage.foldername(name))[1]
);

-- 3) DOG PHOTOS (public reads, owner writes)
create policy if not exists "Users can upload dog photos"
on storage.objects for insert
with check (
  bucket_id = 'dog-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Anyone can view dog photos"
on storage.objects for select
using (bucket_id = 'dog-photos');

create policy if not exists "Users can update own dog photos"
on storage.objects for update
using (
  bucket_id = 'dog-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Users can delete own dog photos"
on storage.objects for delete
using (
  bucket_id = 'dog-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

-- 4) POST IMAGES (public reads, owner writes)
create policy if not exists "Users can upload post images"
on storage.objects for insert
with check (
  bucket_id = 'post-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Anyone can view post images"
on storage.objects for select
using (bucket_id = 'post-images');

create policy if not exists "Users can update own post images"
on storage.objects for update
using (
  bucket_id = 'post-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "Users can delete own post images"
on storage.objects for delete
using (
  bucket_id = 'post-images'
  and auth.uid()::text = (storage.foldername(name))[1]
);

-- 5) CHAT MEDIA (private to match participants)
create policy if not exists "Chat participants can upload media"
on storage.objects for insert
with check (
  bucket_id = 'chat-media'
  and exists (
    select 1 from matches m
    where m.id::text = (storage.foldername(name))[1]
      and (m.user_id = auth.uid() or m.target_user_id = auth.uid())
  )
);

create policy if not exists "Chat participants can read media"
on storage.objects for select
using (
  bucket_id = 'chat-media'
  and exists (
    select 1 from matches m
    where m.id::text = (storage.foldername(name))[1]
      and (m.user_id = auth.uid() or m.target_user_id = auth.uid())
  )
);

create policy if not exists "Uploader can update own chat media"
on storage.objects for update
using (
  bucket_id = 'chat-media'
  and auth.uid()::text = (storage.foldername(name))[2]
  and exists (
    select 1 from matches m
    where m.id::text = (storage.foldername(name))[1]
      and (m.user_id = auth.uid() or m.target_user_id = auth.uid())
  )
);

create policy if not exists "Uploader can delete own chat media"
on storage.objects for delete
using (
  bucket_id = 'chat-media'
  and auth.uid()::text = (storage.foldername(name))[2]
  and exists (
    select 1 from matches m
    where m.id::text = (storage.foldername(name))[1]
      and (m.user_id = auth.uid() or m.target_user_id = auth.uid())
  )
);

-- 6) PLAYDATE ALBUMS (participants only)
create policy if not exists "Participants can upload playdate photos"
on storage.objects for insert
with check (
  bucket_id = 'playdate-albums'
  and exists (
    select 1 from playdate_participants pp
    where pp.playdate_id::text = (storage.foldername(name))[1]
      and pp.user_id = auth.uid()
  )
);

create policy if not exists "Participants can view playdate photos"
on storage.objects for select
using (
  bucket_id = 'playdate-albums'
  and exists (
    select 1 from playdate_participants pp
    where pp.playdate_id::text = (storage.foldername(name))[1]
      and pp.user_id = auth.uid()
  )
);

create policy if not exists "Uploader can update own playdate photos"
on storage.objects for update
using (
  bucket_id = 'playdate-albums'
  and auth.uid()::text = (storage.foldername(name))[2]
  and exists (
    select 1 from playdate_participants pp
    where pp.playdate_id::text = (storage.foldername(name))[1]
      and pp.user_id = auth.uid()
  )
);

create policy if not exists "Uploader can delete own playdate photos"
on storage.objects for delete
using (
  bucket_id = 'playdate-albums'
  and auth.uid()::text = (storage.foldername(name))[2]
  and exists (
    select 1 from playdate_participants pp
    where pp.playdate_id::text = (storage.foldername(name))[1]
      and pp.user_id = auth.uid()
  )
);


