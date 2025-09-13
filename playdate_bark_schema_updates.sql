-- BarkDate: Bark Notifications & Playdate System Database Updates
-- Schema enhancements for implementing bark notifications and advanced playdate management

-- =====================================================
-- 1. BARK TRACKING ENHANCEMENTS
-- =====================================================

-- Add bark tracking to matches table to prevent spam
ALTER TABLE matches ADD COLUMN IF NOT EXISTS bark_count integer DEFAULT 0;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS last_bark_at timestamp with time zone;

-- Update existing matches to have bark_count = 1 where action = 'bark'
UPDATE matches SET bark_count = 1 WHERE action = 'bark' AND bark_count = 0;

-- =====================================================
-- 2. PLAYDATE REQUEST SYSTEM
-- =====================================================

-- Enhanced playdate requests table for managing invitations
CREATE TABLE IF NOT EXISTS playdate_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invitee_dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'counter_proposed')),
  message text,
  counter_proposal jsonb, -- For time/location changes: {"time": "2024-01-15T14:00:00Z", "location": "Central Park"}
  created_at timestamp with time zone DEFAULT now(),
  responded_at timestamp with time zone,
  UNIQUE(playdate_id, invitee_id, invitee_dog_id)
);

-- =====================================================
-- 3. PLAYDATE RECAPS & REVIEWS
-- =====================================================

-- Playdate recaps for post-playdate experiences
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
  post_id uuid REFERENCES posts(id), -- If shared as a social post
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(playdate_id, user_id, dog_id)
);

-- =====================================================
-- 4. ENHANCED NOTIFICATIONS
-- =====================================================

-- Add enhanced notification fields for better categorization
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_type text;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_id uuid; -- playdate_id, user_id, dog_id, etc.
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata jsonb; -- Additional data for notifications

-- Update existing notification types to include bark notifications
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
  CHECK (type IN ('match', 'message', 'playdate', 'achievement', 'system', 'bark', 'playdate_request', 'playdate_update'));

-- =====================================================
-- 5. ENHANCED PLAYDATES TABLE
-- =====================================================

-- Add helpful fields to playdates table
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS creator_dog_id uuid REFERENCES dogs(id);
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}'; -- ["outdoor", "small_dogs", "training"]
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT false; -- For future group playdates
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS weather_dependent boolean DEFAULT false;
ALTER TABLE playdates ADD COLUMN IF NOT EXISTS notes text; -- Private notes for organizer

-- =====================================================
-- 6. DOG FRIENDSHIPS/CONNECTIONS
-- =====================================================

-- Track dog friendships formed through successful playdates
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

-- =====================================================
-- 7. PERFORMANCE INDEXES
-- =====================================================

-- Indexes for bark tracking
CREATE INDEX IF NOT EXISTS idx_matches_bark_count ON matches(bark_count) WHERE bark_count > 0;
CREATE INDEX IF NOT EXISTS idx_matches_last_bark_at ON matches(last_bark_at);

-- Indexes for playdate requests
CREATE INDEX IF NOT EXISTS idx_playdate_requests_invitee ON playdate_requests(invitee_id, status);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_requester ON playdate_requests(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_playdate ON playdate_requests(playdate_id);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_action_type ON notifications(user_id, action_type, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_related_id ON notifications(related_id) WHERE related_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read, created_at) WHERE is_read = false;

-- Indexes for playdate recaps
CREATE INDEX IF NOT EXISTS idx_playdate_recaps_user ON playdate_recaps(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_playdate_recaps_playdate ON playdate_recaps(playdate_id);
CREATE INDEX IF NOT EXISTS idx_playdate_recaps_shared ON playdate_recaps(shared_to_feed) WHERE shared_to_feed = true;

-- Indexes for dog friendships
CREATE INDEX IF NOT EXISTS idx_dog_friendships_dog1 ON dog_friendships(dog1_id, friendship_level);
CREATE INDEX IF NOT EXISTS idx_dog_friendships_dog2 ON dog_friendships(dog2_id, friendship_level);

-- =====================================================
-- 8. ROW LEVEL SECURITY POLICIES
-- =====================================================

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

-- Notifications policies (view/insert own)
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own notifications" ON notifications;
CREATE POLICY "Users can insert own notifications" ON notifications
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Playdate recaps policies
DROP POLICY IF EXISTS "Users can view recaps for playdates they participated in" ON playdate_recaps;
CREATE POLICY "Users can view recaps for playdates they participated in" ON playdate_recaps
  FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM playdates p 
      WHERE p.id = playdate_id AND (p.organizer_id = auth.uid() OR p.participant_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can create recaps for their own playdates" ON playdate_recaps;
CREATE POLICY "Users can create recaps for their own playdates" ON playdate_recaps
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM playdates p 
      WHERE p.id = playdate_id AND (p.organizer_id = auth.uid() OR p.participant_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can update their own recaps" ON playdate_recaps;
CREATE POLICY "Users can update their own recaps" ON playdate_recaps
  FOR UPDATE USING (user_id = auth.uid());

-- Dog friendships policies
DROP POLICY IF EXISTS "Users can view friendships for their dogs" ON dog_friendships;
CREATE POLICY "Users can view friendships for their dogs" ON dog_friendships
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM dogs d WHERE d.id = dog1_id AND d.user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM dogs d WHERE d.id = dog2_id AND d.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "Users can create friendships for their dogs" ON dog_friendships;
CREATE POLICY "Users can create friendships for their dogs" ON dog_friendships
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM dogs d WHERE d.id = dog1_id AND d.user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM dogs d WHERE d.id = dog2_id AND d.user_id = auth.uid())
  );

-- =====================================================
-- 9. HELPER FUNCTIONS
-- =====================================================

-- Function to automatically create dog friendship after successful playdate
CREATE OR REPLACE FUNCTION create_dog_friendship_after_playdate()
RETURNS TRIGGER AS $$
BEGIN
  -- Only create friendship when playdate is marked as completed
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Get all dogs from this playdate and create friendships
    INSERT INTO dog_friendships (dog1_id, dog2_id, formed_through_playdate_id)
    SELECT DISTINCT 
      LEAST(pp1.dog_id, pp2.dog_id),
      GREATEST(pp1.dog_id, pp2.dog_id),
      NEW.id
    FROM playdate_participants pp1
    CROSS JOIN playdate_participants pp2
    WHERE pp1.playdate_id = NEW.id 
      AND pp2.playdate_id = NEW.id
      AND pp1.dog_id != pp2.dog_id
    ON CONFLICT (dog1_id, dog2_id) DO UPDATE SET
      updated_at = now(),
      friendship_level = CASE 
        WHEN dog_friendships.friendship_level = 'acquaintance' THEN 'friend'
        WHEN dog_friendships.friendship_level = 'friend' THEN 'best_friend'
        ELSE dog_friendships.friendship_level
      END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create dog friendships
DROP TRIGGER IF EXISTS trigger_create_dog_friendship ON playdates;
CREATE TRIGGER trigger_create_dog_friendship
  AFTER UPDATE ON playdates
  FOR EACH ROW
  EXECUTE FUNCTION create_dog_friendship_after_playdate();

-- =====================================================
-- 10. SAMPLE DATA FOR TESTING
-- =====================================================

-- Add some sample playdate requests (only if tables are empty)
INSERT INTO playdate_requests (playdate_id, requester_id, invitee_id, invitee_dog_id, status, message)
SELECT 
  p.id,
  p.organizer_id,
  p.participant_id,
  d.id,
  'pending',
  'Would love to have a playdate with your pup!'
FROM playdates p
JOIN dogs d ON d.user_id = p.participant_id
WHERE NOT EXISTS (SELECT 1 FROM playdate_requests LIMIT 1)
LIMIT 3;

-- Add some sample notifications for barks
INSERT INTO notifications (user_id, title, body, type, action_type, related_id, is_read)
SELECT 
  d2.user_id,
  d1.name || ' barked at ' || d2.name || '! 🐕',
  'Someone is interested in meeting your pup!',
  'bark',
  'bark_received',
  d1.id,
  false
FROM dogs d1
CROSS JOIN dogs d2
WHERE d1.user_id != d2.user_id
  AND NOT EXISTS (SELECT 1 FROM notifications WHERE type = 'bark' LIMIT 1)
LIMIT 5;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Verify tables were created successfully
SELECT 
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('playdate_requests', 'playdate_recaps', 'dog_friendships')
ORDER BY table_name;

-- Verify new columns were added
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('matches', 'notifications', 'playdates')
  AND column_name IN ('bark_count', 'last_bark_at', 'action_type', 'related_id', 'metadata', 'creator_dog_id', 'tags')
ORDER BY table_name, column_name;

-- Check sample data
SELECT 'playdate_requests' as table_name, count(*) as record_count FROM playdate_requests
UNION ALL
SELECT 'notifications (barks)', count(*) FROM notifications WHERE type = 'bark'
UNION ALL  
SELECT 'dog_friendships', count(*) FROM dog_friendships;
