-- Sprint 7f: server-computed unread-conversation count.
-- Replaces the client-side `streamConversations` derivation which was lossy
-- on group messages (receiver_id IS NULL) because Supabase realtime cannot
-- apply the .or filter server-side.

create or replace function unread_conversations_count(p_user_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  -- Privacy: callers can only fetch their own count.
  if auth.uid() is null or auth.uid() <> p_user_id then
    return 0;
  end if;

  select count(distinct match_id)::int into v_count
  from messages m
  where m.is_read = false
    and m.sender_id <> p_user_id
    and (
      m.receiver_id = p_user_id
      or (
        m.receiver_id is null
        and exists (
          select 1 from conversation_participants cp
          where cp.conversation_id = m.match_id
            and cp.user_id = p_user_id
        )
      )
    );

  return coalesce(v_count, 0);
end;
$$;

grant execute on function unread_conversations_count(uuid) to authenticated;
