-- 1. Fix Messages Foreign Key
-- The app uses 'conversations' table but 'messages' table was pointing to 'matches'.
-- We update the FK to point to 'conversations' instead.

ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_match_id_fkey;

ALTER TABLE messages 
ADD CONSTRAINT messages_match_id_fkey 
FOREIGN KEY (match_id) REFERENCES conversations(id)
ON DELETE CASCADE;

-- 2. Create Dashboard Stats Function
-- Returns counts for the dashboard: Barks (Friends), Playdates (Active), Alerts (Unread)

CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of creator (to access all tables)
AS $$
DECLARE
  v_barks_count integer;
  v_playdates_count integer;
  v_alerts_count integer;
BEGIN
  -- Count Barks (Friends/Pack Members)
  -- Counts confirmed friendships for any of the user's dogs
  SELECT count(*) INTO v_barks_count
  FROM dog_friendships df
  WHERE df.status = 'accepted'
  AND (
    df.dog_id IN (SELECT id FROM dogs WHERE user_id = p_user_id) 
    OR 
    df.friend_dog_id IN (SELECT id FROM dogs WHERE user_id = p_user_id)
  );

  -- Count Upcoming Playdates
  SELECT count(*) INTO v_playdates_count
  FROM playdates p
  WHERE (p.creator_dog_id IN (SELECT id FROM dogs WHERE user_id = p_user_id)
         OR p.invited_dog_id IN (SELECT id FROM dogs WHERE user_id = p_user_id))
  AND p.status IN ('accepted', 'confirmed')
  AND p.date_time > now();

  -- Count Unread Notifications
  SELECT count(*) INTO v_alerts_count
  FROM notifications n
  WHERE n.user_id = p_user_id
  AND n.is_read = false;

  RETURN json_build_object(
    'barks', v_barks_count,
    'playdates', v_playdates_count,
    'alerts', v_alerts_count
  );
END;
$$;
