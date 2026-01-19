-- Fix get_dashboard_stats function
-- The original function used wrong column names that don't exist in the schema
-- This version uses the correct columns: organizer_id, participant_id, scheduled_at

CREATE OR REPLACE FUNCTION get_dashboard_stats(p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Count Upcoming Playdates (using correct column names)
  SELECT count(*) INTO v_playdates_count
  FROM playdates p
  WHERE (p.organizer_id = p_user_id OR p.participant_id = p_user_id)
  AND p.status IN ('accepted', 'confirmed', 'pending')
  AND p.scheduled_at > now();

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
