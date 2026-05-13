-- Map & Location System Redesign Migration
-- Created: 2025-12-15
-- Features: Live location tracking, Home parks (top 3), Park status reports

-- ============================================
-- 1. LIVE LOCATION TRACKING FOR USERS
-- ============================================

-- Add live location columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS live_latitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS live_longitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS live_location_updated_at TIMESTAMP WITH TIME ZONE;

-- Privacy setting: 'off', 'friends', 'all'
ALTER TABLE users ADD COLUMN IF NOT EXISTS live_location_privacy TEXT DEFAULT 'off' 
  CHECK (live_location_privacy IN ('off', 'friends', 'all'));

-- Create index for efficient nearby user queries
CREATE INDEX IF NOT EXISTS idx_users_live_location 
  ON users(live_latitude, live_longitude) 
  WHERE live_location_privacy != 'off' AND live_latitude IS NOT NULL;

-- ============================================
-- 2. TOP 3 PARKS (FAVORITES) FOR DOGS
-- ============================================

-- Add favorite parks to dogs (stored as JSON array)
-- Format: [{"park_id": "...", "park_name": "...", "is_home": true}, ...]
ALTER TABLE dogs ADD COLUMN IF NOT EXISTS favorite_parks JSONB DEFAULT '[]'::jsonb;

-- ============================================
-- 3. PARK STATUS REPORTS
-- ============================================

-- Create park status reports table
CREATE TABLE IF NOT EXISTS park_status_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Park identification (using Google Place ID)
  park_id TEXT NOT NULL,
  park_name TEXT NOT NULL,
  park_latitude DOUBLE PRECISION,
  park_longitude DOUBLE PRECISION,
  
  -- Reporter info
  reporter_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  
  -- Status details
  status TEXT NOT NULL CHECK (status IN ('closed', 'crowded', 'quiet', 'hazard', 'other')),
  message TEXT,
  
  -- Verification by other users
  is_verified BOOLEAN DEFAULT false,
  verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
  verified_at TIMESTAMP WITH TIME ZONE,
  
  -- Counter-reports (marked as not true)
  dispute_count INTEGER DEFAULT 0,
  
  -- Auto-expire after 4 hours by default
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '4 hours'),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes for park status queries
CREATE INDEX IF NOT EXISTS idx_park_status_park_id ON park_status_reports(park_id);
CREATE INDEX IF NOT EXISTS idx_park_status_expires ON park_status_reports(expires_at);
CREATE INDEX IF NOT EXISTS idx_park_status_created ON park_status_reports(created_at DESC);

-- ============================================
-- 4. RLS POLICIES
-- ============================================

-- Enable RLS on new table
ALTER TABLE park_status_reports ENABLE ROW LEVEL SECURITY;

-- Anyone can view active (non-expired) status reports
CREATE POLICY "Anyone can view active park status reports"
  ON park_status_reports
  FOR SELECT
  USING (expires_at > NOW());

-- Authenticated users can create reports
CREATE POLICY "Authenticated users can create park status reports"
  ON park_status_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (reporter_user_id = auth.uid());

-- Users can update their own reports
CREATE POLICY "Users can update their own park status reports"
  ON park_status_reports
  FOR UPDATE
  TO authenticated
  USING (reporter_user_id = auth.uid());

-- ============================================
-- 5. HELPER FUNCTION: Get active status for a park
-- ============================================

CREATE OR REPLACE FUNCTION get_park_status(p_park_id TEXT)
RETURNS TABLE (
  status TEXT,
  message TEXT,
  reporter_name TEXT,
  is_verified BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE,
  hours_ago DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    psr.status,
    psr.message,
    u.name as reporter_name,
    psr.is_verified,
    psr.created_at,
    EXTRACT(EPOCH FROM (NOW() - psr.created_at)) / 3600.0 as hours_ago
  FROM park_status_reports psr
  LEFT JOIN users u ON u.id = psr.reporter_user_id
  WHERE psr.park_id = p_park_id
    AND psr.expires_at > NOW()
  ORDER BY psr.created_at DESC
  LIMIT 1;
END;
$$;

-- ============================================
-- 6. HELPER FUNCTION: Get nearby live users
-- ============================================

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
    -- Haversine distance calculation
    (6371 * acos(
      cos(radians(p_latitude)) * cos(radians(u.live_latitude)) *
      cos(radians(u.live_longitude) - radians(p_longitude)) +
      sin(radians(p_latitude)) * sin(radians(u.live_latitude))
    )) as distance_km
  FROM users u
  -- Join with dogs table to get first dog's info
  LEFT JOIN LATERAL (
    SELECT d.name, d.main_photo_url
    FROM dogs d
    WHERE d.owner_id = u.id
    ORDER BY d.created_at
    LIMIT 1
  ) dog ON true
  WHERE u.id != p_user_id
    AND u.live_latitude IS NOT NULL
    AND u.live_longitude IS NOT NULL
    AND u.live_location_privacy != 'off'
    -- Show if updated in last 4 hours (for colored ring: green/orange/red)
    AND u.live_location_updated_at > NOW() - INTERVAL '4 hours'
    -- Filter by privacy setting
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
    -- Distance filter
    AND (6371 * acos(
      cos(radians(p_latitude)) * cos(radians(u.live_latitude)) *
      cos(radians(u.live_longitude) - radians(p_longitude)) +
      sin(radians(p_latitude)) * sin(radians(u.live_latitude))
    )) <= p_radius_km
  ORDER BY distance_km;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_park_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_nearby_live_users TO authenticated;
