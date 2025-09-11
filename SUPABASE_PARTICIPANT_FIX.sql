-- Fix any existing playdates that might have NULL participant_id
-- This should only be needed if there are legacy records

-- Check for playdates with NULL participant_id
SELECT COUNT(*) as null_participants 
FROM playdates 
WHERE participant_id IS NULL;

-- If there are any NULL participant_id records, we could either:
-- 1. Delete them if they're orphaned
-- 2. Set participant_id based on the playdate_requests table

-- Option 2: Fix participant_id based on accepted requests
UPDATE playdates 
SET participant_id = pr.invitee_id
FROM playdate_requests pr 
WHERE playdates.id = pr.playdate_id 
  AND pr.status = 'accepted' 
  AND playdates.participant_id IS NULL;

-- Clean up any remaining orphaned playdates
DELETE FROM playdates 
WHERE participant_id IS NULL 
  AND id NOT IN (
    SELECT DISTINCT playdate_id 
    FROM playdate_requests 
    WHERE status = 'pending'
  );
