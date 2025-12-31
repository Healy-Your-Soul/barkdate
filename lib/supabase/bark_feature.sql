-- ============================================
-- BARK FEATURE SQL
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. CREATE BARKS TABLE
CREATE TABLE IF NOT EXISTS barks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  to_dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  
  -- Prevent duplicate barks in same moment
  CONSTRAINT unique_bark_moment UNIQUE (from_dog_id, to_dog_id, created_at)
);

-- 2. CREATE INDEXES
CREATE INDEX IF NOT EXISTS idx_barks_from_dog ON barks(from_dog_id);
CREATE INDEX IF NOT EXISTS idx_barks_to_dog ON barks(to_dog_id);
CREATE INDEX IF NOT EXISTS idx_barks_created_at ON barks(created_at);

-- 3. ENABLE RLS
ALTER TABLE barks ENABLE ROW LEVEL SECURITY;

-- 4. CREATE POLICIES
-- Anyone can read barks (to show notification count)
CREATE POLICY "Anyone can read barks" ON barks
  FOR SELECT USING (true);

-- Authenticated users can insert barks
CREATE POLICY "Authenticated users can insert barks" ON barks
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Users can delete their own barks
CREATE POLICY "Users can delete their own barks" ON barks
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = from_dog_id AND d.user_id = auth.uid()
    )
  );

-- 5. GRANT PERMISSIONS
GRANT ALL ON barks TO authenticated;
GRANT SELECT ON barks TO anon;

-- 6. CREATE FUNCTION TO CHECK BARK LIMIT
-- Non-friends can only bark 3 times per day to the same dog
CREATE OR REPLACE FUNCTION can_bark(sender_dog_id uuid, receiver_dog_id uuid)
RETURNS boolean AS $$
DECLARE
  is_friend boolean;
  bark_count integer;
BEGIN
  -- Check if they are already friends
  SELECT EXISTS (
    SELECT 1 FROM dog_friendships 
    WHERE status = 'accepted'
    AND (
      (dog_id = sender_dog_id AND friend_dog_id = receiver_dog_id)
      OR (dog_id = receiver_dog_id AND friend_dog_id = sender_dog_id)
    )
  ) INTO is_friend;
  
  -- Friends can bark unlimited
  IF is_friend THEN
    RETURN true;
  END IF;
  
  -- Non-friends: count barks in last 24 hours
  SELECT COUNT(*) INTO bark_count
  FROM barks
  WHERE from_dog_id = sender_dog_id
    AND to_dog_id = receiver_dog_id
    AND created_at > now() - interval '24 hours';
  
  -- Allow if under limit (3 barks per day)
  RETURN bark_count < 3;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. CREATE TRIGGER FOR BARK NOTIFICATION
-- Automatically creates a notification when barked at
CREATE OR REPLACE FUNCTION notify_bark()
RETURNS TRIGGER AS $$
DECLARE
  receiver_user_id uuid;
  sender_dog_name text;
BEGIN
  -- Get receiver's user_id
  SELECT user_id INTO receiver_user_id
  FROM dogs WHERE id = NEW.to_dog_id;
  
  -- Get sender dog's name
  SELECT name INTO sender_dog_name
  FROM dogs WHERE id = NEW.from_dog_id;
  
  -- Create notification
  INSERT INTO notifications (user_id, title, body, type, data)
  VALUES (
    receiver_user_id,
    '🐕 Woof!',
    sender_dog_name || ' barked at you!',
    'bark',
    jsonb_build_object(
      'from_dog_id', NEW.from_dog_id,
      'to_dog_id', NEW.to_dog_id,
      'bark_id', NEW.id
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_bark_notification ON barks;
CREATE TRIGGER trigger_bark_notification
AFTER INSERT ON barks
FOR EACH ROW
EXECUTE FUNCTION notify_bark();

-- 8. ACHIEVEMENT: "Social Butterfly" now also counts barks
-- (Optional - adds barks to friendship tracking)
