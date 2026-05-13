-- Backfill dog location coordinates from owners
-- Ensures older dog profiles inherit the latest owner location
-- Generated on 2025-10-19

BEGIN;

-- Populate missing dog coordinates using their owner's current location
UPDATE dogs AS d
SET
  latitude = u.latitude,
  longitude = u.longitude,
  updated_at = NOW()
FROM users AS u
WHERE d.user_id = u.id
  AND d.latitude IS NULL
  AND u.latitude IS NOT NULL
  AND u.longitude IS NOT NULL;

-- Ensure owners with coordinates have a location_updated_at timestamp
UPDATE users
SET location_updated_at = NOW()
WHERE latitude IS NOT NULL
  AND longitude IS NOT NULL
  AND location_updated_at IS NULL;

COMMIT;
