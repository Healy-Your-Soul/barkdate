-- Run this to update the get_nearby_live_users function
-- Drop the old function first (return type changed)
DROP FUNCTION IF EXISTS get_nearby_live_users(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

-- Recreate with new columns (dog_name, dog_photo_url) and 4-hour timeout
CREATE OR REPLACE FUNCTION get_nearby_live_users(
  p_user_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 5.0
)
RETURNS TABLE (
  user_id UUID,
  user_name TEXT,
  avatar_url TEXT,
  dog_name TEXT,
  dog_photo_url TEXT,
  live_latitude DOUBLE PRECISION,
  live_longitude DOUBLE PRECISION,
  live_location_updated_at TIMESTAMP WITH TIME ZONE,
  is_friend BOOLEAN,
  distance_km DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id as user_id,
    u.name as user_name,
    u.avatar_url,
    dog.name as dog_name,
    dog.main_photo_url as dog_photo_url,
    u.live_latitude,
    u.live_longitude,
    u.live_location_updated_at,
    EXISTS(
      SELECT 1 FROM matches m 
      WHERE m.is_mutual = true 
        AND ((m.user_id = p_user_id AND m.target_user_id = u.id)
          OR (m.target_user_id = p_user_id AND m.user_id = u.id))
    ) as is_friend,
    (6371 * acos(
      cos(radians(p_latitude)) * cos(radians(u.live_latitude)) *
      cos(radians(u.live_longitude) - radians(p_longitude)) +
      sin(radians(p_latitude)) * sin(radians(u.live_latitude))
    )) as distance_km
  FROM users u
  LEFT JOIN LATERAL (
    SELECT d.name, d.main_photo_url
    FROM dogs d
    WHERE d.user_id = u.id
    ORDER BY d.created_at
    LIMIT 1
  ) dog ON true
  WHERE u.id != p_user_id
    AND u.live_latitude IS NOT NULL
    AND u.live_longitude IS NOT NULL
    AND u.live_location_privacy != 'off'
    AND u.live_location_updated_at > NOW() - INTERVAL '4 hours'
    AND (
      u.live_location_privacy = 'all'
      OR (
        u.live_location_privacy = 'friends'
        AND EXISTS(
          SELECT 1 FROM matches m 
          WHERE m.is_mutual = true 
            AND ((m.user_id = p_user_id AND m.target_user_id = u.id)
              OR (m.target_user_id = p_user_id AND m.user_id = u.id))
        )
      )
    )
    AND (6371 * acos(
      cos(radians(p_latitude)) * cos(radians(u.live_latitude)) *
      cos(radians(u.live_longitude) - radians(p_longitude)) +
      sin(radians(p_latitude)) * sin(radians(u.live_latitude))
    )) <= p_radius_km
  ORDER BY distance_km;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_nearby_live_users TO authenticated;
