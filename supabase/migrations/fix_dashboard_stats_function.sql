-- =====================================================
-- FIX: Database Functions with Wrong Column References
-- =====================================================
-- This migration fixes two functions that reference non-existent columns.
-- Run this in Supabase SQL Editor to fix the errors.

-- =====================================================
-- 1. FIX: get_dashboard_stats function
-- =====================================================
-- Original error: column p.invited_dog_id does not exist
-- Fix: Changed creator_dog_id → organizer_id, invited_dog_id → participant_id, date_time → scheduled_at

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

-- =====================================================
-- 2. FIX: search_dogs_for_playdate function
-- =====================================================
-- Original error: column d.owner_id does not exist
-- Fix: Changed owner_id → user_id throughout the function

CREATE OR REPLACE FUNCTION search_dogs_for_playdate(
  search_query text,
  user_id uuid,
  limit_count int DEFAULT 20
)
RETURNS TABLE (
  id uuid,
  name text,
  breed text,
  avatar_url text,
  is_friend boolean,
  owner_id uuid,
  owner_name text
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  WITH friend_dogs AS (
    -- Dogs belonging to friends
    SELECT 
      d.id, d.name, d.breed, d.main_photo_url as avatar_url, 
      true as is_friend, d.user_id as owner_id, u.name as owner_name
    FROM dogs d
    JOIN users u ON d.user_id = u.id
    WHERE d.user_id IN (
      SELECT CASE 
        WHEN requester_id = search_dogs_for_playdate.user_id THEN receiver_id 
        ELSE requester_id 
      END
      FROM friendships 
      WHERE (requester_id = search_dogs_for_playdate.user_id OR receiver_id = search_dogs_for_playdate.user_id) 
      AND status = 'accepted'
    )
    AND (search_query IS NULL OR d.name ILIKE '%' || search_query || '%')
  ),
  public_dogs AS (
    -- Other public dogs
    SELECT 
      d.id, d.name, d.breed, d.main_photo_url as avatar_url, 
      false as is_friend, d.user_id as owner_id, u.name as owner_name
    FROM dogs d
    JOIN users u ON d.user_id = u.id
    WHERE d.is_public = true
    AND d.user_id != search_dogs_for_playdate.user_id -- Exclude own dogs
    AND d.id NOT IN (SELECT fd.id FROM friend_dogs fd) -- Exclude already found friend dogs
    AND (search_query IS NULL OR d.name ILIKE '%' || search_query || '%')
  )
  SELECT * FROM friend_dogs
  UNION ALL
  SELECT * FROM public_dogs
  LIMIT limit_count;
END;
$$;
