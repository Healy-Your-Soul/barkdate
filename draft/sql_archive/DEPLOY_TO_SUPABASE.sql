-- ===================================================================
-- COMPLETE SUPABASE DEPLOYMENT SCRIPT FOR BARKDATE
-- ===================================================================
-- Run this entire script in your Supabase SQL Editor to fix all issues
-- This includes the notification RPC function and schema updates

-- ===================================================================
-- 1. CREATE NOTIFICATION RPC FUNCTION (FIXES RLS ISSUE)
-- ===================================================================

CREATE OR REPLACE FUNCTION public.create_notification(
  user_id uuid,
  title text,
  body text,
  type text,
  action_type text DEFAULT NULL,
  related_id text DEFAULT NULL,
  metadata jsonb DEFAULT NULL,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
) RETURNS notifications
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  res notifications%ROWTYPE;
BEGIN
  INSERT INTO notifications(
    user_id, title, body, type, action_type, related_id, metadata, is_read, created_at
  ) VALUES (
    user_id, title, body, type, action_type, related_id, metadata, is_read, created_at
  ) RETURNING * INTO res;

  RETURN res;
END;
$$;

-- ===================================================================
-- 2. ENSURE ALL REQUIRED TABLES EXIST
-- ===================================================================

-- Playdate requests table
CREATE TABLE IF NOT EXISTS playdate_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'counter_proposed')),
  message text,
  counter_proposal jsonb,
  created_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  UNIQUE(playdate_id, invitee_id, invitee_dog_id)
);

-- Playdate recaps table
CREATE TABLE IF NOT EXISTS playdate_recaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  experience_rating integer CHECK (experience_rating >= 1 AND experience_rating <= 5),
  location_rating integer CHECK (location_rating >= 1 AND location_rating <= 5),
  recap_text text,
  photos text[] DEFAULT '{}',
  shared_to_feed boolean DEFAULT false,
  post_id uuid REFERENCES posts(id),
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(playdate_id, user_id, dog_id)
);

-- Dog friendships table
CREATE TABLE IF NOT EXISTS dog_friendships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dog1_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  dog2_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  formed_through_playdate_id uuid REFERENCES playdates(id),
  friendship_level text DEFAULT 'acquaintance' CHECK (friendship_level IN ('acquaintance', 'friend', 'best_friend')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE(dog1_id, dog2_id),
  CHECK(dog1_id != dog2_id)
);

-- ===================================================================
-- 3. ADD MISSING COLUMNS TO EXISTING TABLES
-- ===================================================================

-- Add bark tracking to matches table
ALTER TABLE matches ADD COLUMN IF NOT EXISTS bark_count integer DEFAULT 0;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS last_bark_at timestamp with time zone;

-- Add enhanced notification fields
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type text;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_id text;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata jsonb;

-- Add helpful fields to playdates table
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS creator_dog_id uuid REFERENCES dogs(id);
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT false;
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS weather_dependent boolean DEFAULT false;
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS notes text;

-- ===================================================================
-- 4. UPDATE RLS POLICIES
-- ===================================================================

-- Enable RLS on new tables
ALTER TABLE playdate_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdate_recaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE dog_friendships ENABLE ROW LEVEL SECURITY;

-- Playdate requests policies
DROP POLICY IF EXISTS "Users can view requests involving them" ON playdate_requests;
CREATE POLICY "Users can view requests involving them" ON playdate_requests
  FOR SELECT USING (
    requester_id = auth.uid() OR 
    invitee_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM playdates p 
      WHERE p.id = playdate_id AND (p.organizer_id = auth.uid() OR p.participant_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create requests for their playdates" ON playdate_requests;
CREATE POLICY "Users can create requests for their playdates" ON playdate_requests
  FOR INSERT WITH CHECK (
    requester_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM playdates p 
      WHERE p.id = playdate_id AND p.organizer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update requests they received" ON playdate_requests;
CREATE POLICY "Users can update requests they received" ON playdate_requests
  FOR UPDATE USING (invitee_id = auth.uid() OR requester_id = auth.uid());

-- Update notification policies to allow system creation
DROP POLICY IF EXISTS "System can create notifications" ON notifications;
CREATE POLICY "System can create notifications" ON notifications
  FOR INSERT WITH CHECK (true);

-- ===================================================================
-- 5. CREATE PERFORMANCE INDEXES
-- ===================================================================

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_action_type ON notifications(user_id, action_type, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_related_id ON notifications(related_id) WHERE related_id IS NOT NULL;

-- Indexes for playdate requests
CREATE INDEX IF NOT EXISTS idx_playdate_requests_invitee ON playdate_requests(invitee_id, status);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester ON playdate_requests(requester_id, status);

-- Indexes for bark tracking
CREATE INDEX IF NOT EXISTS idx_matches_bark_tracking ON matches(user_id, target_user_id, last_bark_at) WHERE bark_count > 0;

-- ===================================================================
-- 6. VERIFICATION
-- ===================================================================

-- Verify the notification function was created
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name = 'create_notification';

-- Verify tables exist
SELECT 
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('playdate_requests', 'playdate_recaps', 'dog_friendships', 'notifications')
ORDER BY table_name;

-- Test the notification function
SELECT public.create_notification(
  auth.uid(),
  'Test Notification',
  'This is a test to verify the function works',
  'system',
  'test',
  null,
  '{"test": true}'::jsonb
) AS test_result;

-- Clean up the test notification
DELETE FROM notifications WHERE title = 'Test Notification' AND type = 'system';

SELECT 'DEPLOYMENT COMPLETE! ✅' as status;
