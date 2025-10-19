-- Enable PostGIS extension for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Add location columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE users ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE users ADD COLUMN IF NOT EXISTS location_updated_at timestamp with time zone;
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_radius_km integer DEFAULT 25;

-- Add location columns to dogs table (inherited from owner)
ALTER TABLE dogs ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE dogs ADD COLUMN IF NOT EXISTS longitude double precision;

-- Seed existing dog coordinates from owner profile when available
UPDATE dogs d
SET latitude = u.latitude,
    longitude = u.longitude
FROM users u
WHERE d.user_id = u.id
  AND u.latitude IS NOT NULL
  AND u.longitude IS NOT NULL
  AND (d.latitude IS NULL OR d.longitude IS NULL);

-- Create spatial index for performance
CREATE INDEX IF NOT EXISTS idx_dogs_location
ON dogs
USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));

-- Create standard indexes for pagination
CREATE INDEX IF NOT EXISTS idx_dogs_created_at ON dogs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_playdates_scheduled_at ON playdates(scheduled_at);

-- Function to find nearby dogs within a radius
CREATE OR REPLACE FUNCTION get_nearby_dogs(
  p_user_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km integer DEFAULT 25,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  name text,
  breed text,
  age integer,
  size text,
  gender text,
  photo_urls text[],
  main_photo_url text,
  bio text,
  is_active boolean,
  distance_km double precision,
  owner_name text,
  owner_avatar_url text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.user_id,
    d.name,
    d.breed,
    d.age,
    d.size,
    d.gender,
    d.photo_urls,
    d.main_photo_url,
    d.bio,
    d.is_active,
    ST_Distance(
      ST_MakePoint(p_longitude, p_latitude)::geography,
      ST_MakePoint(d.longitude, d.latitude)::geography
    ) / 1000 AS distance_km,
    u.name AS owner_name,
    u.avatar_url AS owner_avatar_url
  FROM dogs d
  INNER JOIN users u ON d.user_id = u.id
  WHERE d.user_id != p_user_id
    AND d.is_active = true
    AND d.latitude IS NOT NULL
    AND d.longitude IS NOT NULL
    AND ST_DWithin(
      ST_MakePoint(p_longitude, p_latitude)::geography,
      ST_MakePoint(d.longitude, d.latitude)::geography,
      p_radius_km * 1000
    )
  ORDER BY distance_km ASC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
