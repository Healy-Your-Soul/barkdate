-- Fix for get_user_accessible_dogs function type mismatch
-- Run this in Supabase SQL Editor

DROP FUNCTION IF EXISTS get_user_accessible_dogs(uuid);

CREATE OR REPLACE FUNCTION get_user_accessible_dogs(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  breed text,
  age integer,
  size text,
  gender text,
  bio text,
  main_photo_url text,
  extra_photo_urls text[],
  photo_urls text[],
  vaccinated boolean,
  neutered boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz,
  user_id uuid, -- Keep for backward compatibility
  -- Ownership info
  ownership_type text,
  permissions text[],
  is_primary_owner boolean,
  owner_count bigint,
  owners jsonb -- All owners as JSON array
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    d.id,
    d.name,
    d.breed,
    d.age,
    d.size,
    d.gender,
    d.bio,
    d.main_photo_url,
    d.extra_photo_urls,
    d.photo_urls,
    d.vaccinated,
    d.neutered,
    d.is_active,
    d.created_at,
    d.updated_at,
    d.user_id, -- Keep for backward compatibility
    dog_owner.ownership_type,
    dog_owner.permissions,
    dog_owner.is_primary,
    (SELECT count(*) FROM dog_owners do2 WHERE do2.dog_id = d.id) as owner_count,
    (SELECT jsonb_agg(
      jsonb_build_object(
        'user_id', do3.user_id,
        'user_name', u.name,
        'avatar_url', u.avatar_url,
        'ownership_type', do3.ownership_type,
        'permissions', do3.permissions,
        'is_primary', do3.is_primary,
        'added_at', do3.added_at
      )
      ORDER BY do3.is_primary DESC, do3.added_at ASC
    )
    FROM dog_owners do3
    JOIN users u ON do3.user_id = u.id
    WHERE do3.dog_id = d.id
    ) as owners
  FROM dogs d
  JOIN dog_owners dog_owner ON d.id = dog_owner.dog_id
  WHERE dog_owner.user_id = p_user_id
  AND d.is_active = true
  ORDER BY dog_owner.is_primary DESC, d.created_at DESC;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_accessible_dogs TO authenticated;
