-- ===================================================================
-- SUPABASE FOREIGN KEY FIXES FOR PLAYDATE SYSTEM
-- ===================================================================
-- This fixes the PostgreSQL foreign key relationship errors
-- Run this in your Supabase SQL Editor

-- ===================================================================
-- 1. ADD MISSING FOREIGN KEY RELATIONSHIPS
-- ===================================================================

-- First, let's check what tables exist and their structure
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('playdate_requests', 'dogs', 'users', 'playdates')
ORDER BY table_name, ordinal_position;

-- ===================================================================
-- 2. FIX PLAYDATE_REQUESTS TABLE STRUCTURE
-- ===================================================================

-- Ensure the playdate_requests table has all needed columns
ALTER TABLE playdate_requests 
ADD COLUMN IF NOT EXISTS requester_dog_id uuid REFERENCES dogs(id) ON DELETE CASCADE;

-- Add proper indexes for the relationships that the query expects
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester_dog 
ON playdate_requests(requester_dog_id);

CREATE INDEX IF NOT EXISTS idx_playdate_requests_invitee_dog 
ON playdate_requests(invitee_dog_id);

-- ===================================================================
-- 3. UPDATE PLAYDATE SERVICE QUERIES (ALTERNATIVE APPROACH)
-- ===================================================================

-- Create a simplified view for playdate requests with user/dog info
CREATE OR REPLACE VIEW playdate_requests_with_details AS
SELECT 
    pr.*,
    -- Requester info
    ru.name as requester_name,
    ru.avatar_url as requester_avatar,
    -- Invitee info  
    iu.name as invitee_name,
    iu.avatar_url as invitee_avatar,
    -- Invitee dog info
    id.name as invitee_dog_name,
    id.main_photo_url as invitee_dog_photo,
    id.breed as invitee_dog_breed,
    -- Playdate info
    p.title as playdate_title,
    p.location as playdate_location,
    p.scheduled_at as playdate_scheduled_at,
    p.description as playdate_description,
    p.organizer_id as playdate_organizer_id
FROM playdate_requests pr
LEFT JOIN users ru ON pr.requester_id = ru.id
LEFT JOIN users iu ON pr.invitee_id = iu.id  
LEFT JOIN dogs id ON pr.invitee_dog_id = id.id
LEFT JOIN playdates p ON pr.playdate_id = p.id;

-- ===================================================================
-- 4. CREATE RPC FUNCTION FOR GETTING PENDING REQUESTS
-- ===================================================================

CREATE OR REPLACE FUNCTION get_pending_playdate_requests(user_id_param uuid)
RETURNS TABLE (
    id uuid,
    playdate_id uuid,
    requester_id uuid,
    invitee_id uuid,
    invitee_dog_id uuid,
    status text,
    message text,
    counter_proposal jsonb,
    created_at timestamptz,
    responded_at timestamptz,
    requester_name text,
    requester_avatar text,
    invitee_name text,
    invitee_avatar text,
    invitee_dog_name text,
    invitee_dog_photo text,
    invitee_dog_breed text,
    playdate_title text,
    playdate_location text,
    playdate_scheduled_at timestamptz,
    playdate_description text,
    playdate_organizer_id uuid
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        pr.id,
        pr.playdate_id,
        pr.requester_id,
        pr.invitee_id,
        pr.invitee_dog_id,
        pr.status,
        pr.message,
        pr.counter_proposal,
        pr.created_at,
        pr.responded_at,
        ru.name as requester_name,
        ru.avatar_url as requester_avatar,
        iu.name as invitee_name,
        iu.avatar_url as invitee_avatar,
        id.name as invitee_dog_name,
        id.main_photo_url as invitee_dog_photo,
        id.breed as invitee_dog_breed,
        p.title as playdate_title,
        p.location as playdate_location,
        p.scheduled_at as playdate_scheduled_at,
        p.description as playdate_description,
        p.organizer_id as playdate_organizer_id
    FROM playdate_requests pr
    LEFT JOIN users ru ON pr.requester_id = ru.id
    LEFT JOIN users iu ON pr.invitee_id = iu.id  
    LEFT JOIN dogs id ON pr.invitee_dog_id = id.id
    LEFT JOIN playdates p ON pr.playdate_id = p.id
    WHERE pr.invitee_id = user_id_param 
      AND pr.status = 'pending'
    ORDER BY pr.created_at DESC;
$$;

-- ===================================================================
-- 5. GRANT PERMISSIONS
-- ===================================================================

-- Grant access to the view and function
GRANT SELECT ON playdate_requests_with_details TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_playdate_requests(uuid) TO authenticated;

-- ===================================================================
-- 6. TEST THE FUNCTION
-- ===================================================================

-- Test that the function works (replace with actual user ID)
-- SELECT * FROM get_pending_playdate_requests(auth.uid());

-- ===================================================================
-- 7. UPDATE RLS POLICIES FOR THE VIEW
-- ===================================================================

-- Enable RLS on the view if needed
-- Note: Views inherit RLS from their base tables

SELECT 'FOREIGN KEY FIXES COMPLETE! ✅' as status;

-- Display what we created
SELECT 'Created view: playdate_requests_with_details' as created;
SELECT 'Created function: get_pending_playdate_requests(uuid)' as created;
