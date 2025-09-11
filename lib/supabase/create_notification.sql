-- Server-side helper to create notifications with elevated privileges
-- Run this in your Supabase SQL editor (or include in your DB migration) to create
-- an RPC named `create_notification` that the client can call when RLS prevents
-- direct client inserts into `notifications`.

CREATE OR REPLACE FUNCTION public.create_notification(
  user_id uuid,
  title text,
  body text,
  type text,
  action_type text DEFAULT NULL,
  related_id text DEFAULT NULL,
  metadata jsonb DEFAULT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
) RETURNS notifications
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  res notifications%ROWTYPE;
BEGIN
  INSERT INTO notifications(
    user_id, title, body, type, action_type, related_id, metadata, is_read, created_at
  ) VALUES (
    user_id, title, body, type, action_type, related_id, metadata, is_read, created_at
  ) RETURNING * INTO res;

  RETURN res;
END;
$$;

-- Notes:
-- - SECURITY DEFINER means the function runs with the privileges of its owner.
--   Make sure the function owner is the database role that has permission to
--   insert into `notifications` (for example the role used when running
--   migrations / configured as the DB owner). In Supabase SQL editor you can
--   `SET ROLE` or ensure migrations are run as the right role.
-- - This function's parameter names match the keys passed by the client
--   (notificationData). The client can call:
--     supabase.rpc('create_notification', { user_id: ..., title: ..., body: ..., ... })
-- - After creating the function, no additional policy is required because the
--   function runs with elevated privileges; however ensure your RLS policies
--   still allow the function to perform the insert (SECURITY DEFINER owner
--   must have rights).
