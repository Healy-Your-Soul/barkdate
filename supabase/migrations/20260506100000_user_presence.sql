-- Sprint 7e: track which conversation each user is actively viewing so the
-- push-notification path can skip pushes when the recipient is already in
-- the chat (eliminates iOS-banner-while-in-chat noise).

create table if not exists user_presence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_conversation_id uuid,
  updated_at timestamptz not null default now()
);

create index if not exists idx_user_presence_active_conv
  on user_presence(active_conversation_id);

alter table user_presence enable row level security;

drop policy if exists "Users can read their own presence" on user_presence;
create policy "Users can read their own presence"
  on user_presence for select
  using (auth.uid() = user_id);

-- Sender needs to read recipient's presence to decide whether to push.
drop policy if exists "Authenticated can read presence for push" on user_presence;
create policy "Authenticated can read presence for push"
  on user_presence for select
  to authenticated
  using (true);

drop policy if exists "Users can upsert their own presence" on user_presence;
create policy "Users can upsert their own presence"
  on user_presence for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own presence" on user_presence;
create policy "Users can update their own presence"
  on user_presence for update
  using (auth.uid() = user_id);
