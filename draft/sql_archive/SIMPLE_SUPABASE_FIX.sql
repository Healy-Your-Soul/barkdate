-- ===================================================================
-- SIMPLE SUPABASE FIXES - RUN THESE ONE BY ONE
-- ===================================================================
-- Copy and paste these commands ONE AT A TIME in Supabase SQL Editor
-- Don't run the entire file at once to avoid timeout issues

-- Step 1: Check current table structure
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Step 2: Add missing column to playdate_requests (if needed)
ALTER TABLE playdate_requests 
ADD COLUMN IF NOT EXISTS requester_dog_id uuid REFERENCES dogs(id) ON DELETE CASCADE;

-- Step 3: Create simple RPC function for getting requests
CREATE OR REPLACE FUNCTION get_user_playdate_requests(user_id_param uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', pr.id,
            'playdate_id', pr.playdate_id,
            'requester_id', pr.requester_id,
            'invitee_id', pr.invitee_id,
            'invitee_dog_id', pr.invitee_dog_id,
            'status', pr.status,
            'message', pr.message,
            'created_at', pr.created_at
        )
    ) INTO result
    FROM playdate_requests pr
    WHERE pr.invitee_id = user_id_param 
      AND pr.status = 'pending'
    ORDER BY pr.created_at DESC;
    
    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Step 4: Grant permissions
GRANT EXECUTE ON FUNCTION get_user_playdate_requests(uuid) TO authenticated;

-- Step 5: Test the function (optional)
-- SELECT get_user_playdate_requests(auth.uid());

SELECT 'BASIC FIXES COMPLETE! ✅' as status;
