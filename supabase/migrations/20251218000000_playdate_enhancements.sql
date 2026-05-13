-- Playdate Enhancements Migration
-- 1. Support for multi-dog invites (requester_dog_id)
-- 2. Enhanced location support
-- 3. Indexes for dog search

-- Enable multi-dog invites by adding requester_dog_id to requests
ALTER TABLE playdate_requests 
ADD COLUMN IF NOT EXISTS requester_dog_id uuid REFERENCES dogs(id);

-- Make participant_id nullable in playdates table (we use playdate_participants table now)
ALTER TABLE playdates 
ALTER COLUMN participant_id DROP NOT NULL;

-- Ensure playdates has geo coordinates if missing
ALTER TABLE playdates 
ADD COLUMN IF NOT EXISTS latitude double precision,
ADD COLUMN IF NOT EXISTS longitude double precision,
ADD COLUMN IF NOT EXISTS max_dogs integer DEFAULT 2;

-- Create index for faster dog search (friends/public)
-- Enable the pg_trgm extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_dogs_name_trgm ON dogs USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_dogs_visibility ON dogs(is_public);

-- Update RLS to ensure public dogs are searchable
DROP POLICY IF EXISTS "Public dogs are viewable by everyone" ON dogs;
CREATE POLICY "Public dogs are viewable by everyone"
ON dogs FOR SELECT
USING (is_public = true);

-- Function to search available dogs (friends + public)
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
      true as is_friend, d.owner_id, u.name as owner_name
    FROM dogs d
    JOIN users u ON d.owner_id = u.id
    WHERE d.owner_id IN (
      SELECT CASE 
        WHEN requester_id = user_id THEN receiver_id 
        ELSE requester_id 
      END
      FROM friendships 
      WHERE (requester_id = user_id OR receiver_id = user_id) 
      AND status = 'accepted'
    )
    AND (search_query IS NULL OR d.name ILIKE '%' || search_query || '%')
  ),
  public_dogs AS (
    -- Other public dogs
    SELECT 
      d.id, d.name, d.breed, d.main_photo_url as avatar_url, 
      false as is_friend, d.owner_id, u.name as owner_name
    FROM dogs d
    JOIN users u ON d.owner_id = u.id
    WHERE d.is_public = true
    AND d.owner_id != user_id -- Exclude own dogs
    AND d.id NOT IN (SELECT id FROM friend_dogs) -- Exclude already found friend dogs
    AND (search_query IS NULL OR d.name ILIKE '%' || search_query || '%')
  )
  SELECT * FROM friend_dogs
  UNION ALL
  SELECT * FROM public_dogs
  LIMIT limit_count;
END;
$$;
