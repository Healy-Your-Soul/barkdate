-- ============================================
-- POST TAGGING SYSTEM
-- Instagram-style dog tagging for posts
-- ============================================

-- 1. Create post_tags table
CREATE TABLE IF NOT EXISTS post_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  tagger_dog_id UUID NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,  -- Dog who created the tag
  tagged_dog_id UUID NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,  -- Dog being tagged
  is_collaborator BOOLEAN DEFAULT false,  -- True = contributor credit, False = just tagged
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Constraints
  UNIQUE(post_id, tagged_dog_id)  -- Can't tag same dog twice on same post
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_post_tags_post_id ON post_tags(post_id);
CREATE INDEX IF NOT EXISTS idx_post_tags_tagged_dog ON post_tags(tagged_dog_id);
CREATE INDEX IF NOT EXISTS idx_post_tags_status ON post_tags(status);

-- 3. Enable Row Level Security
ALTER TABLE post_tags ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies

-- Anyone can view approved tags
CREATE POLICY "view_approved_tags" ON post_tags
  FOR SELECT USING (status = 'approved');

-- Tagger can view their own pending tags
CREATE POLICY "tagger_view_pending" ON post_tags
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = post_tags.tagger_dog_id 
      AND d.user_id = auth.uid()
    )
  );

-- Tagged dog owner can view tags awaiting their approval
CREATE POLICY "tagged_view_pending" ON post_tags
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = post_tags.tagged_dog_id 
      AND d.user_id = auth.uid()
    )
  );

-- Anyone can insert tags (will be pending unless friend)
CREATE POLICY "insert_tags" ON post_tags
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = post_tags.tagger_dog_id 
      AND d.user_id = auth.uid()
    )
  );

-- Tagged dog owner can update status (approve/reject)
CREATE POLICY "tagged_update_status" ON post_tags
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = post_tags.tagged_dog_id 
      AND d.user_id = auth.uid()
    )
  );

-- Tagger can delete their own tags
CREATE POLICY "tagger_delete" ON post_tags
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM dogs d 
      WHERE d.id = post_tags.tagger_dog_id 
      AND d.user_id = auth.uid()
    )
  );

-- 5. Function to auto-approve friend tags
CREATE OR REPLACE FUNCTION auto_approve_friend_tags()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if tagger and tagged dogs are friends
  IF EXISTS (
    SELECT 1 FROM dog_friendships df
    WHERE (
      (df.dog_id = NEW.tagger_dog_id AND df.friend_dog_id = NEW.tagged_dog_id)
      OR (df.dog_id = NEW.tagged_dog_id AND df.friend_dog_id = NEW.tagger_dog_id)
    )
    AND df.status = 'accepted'
  ) THEN
    -- Auto-approve for friends
    NEW.status := 'approved';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Trigger to run auto-approval
DROP TRIGGER IF EXISTS trigger_auto_approve_friend_tags ON post_tags;
CREATE TRIGGER trigger_auto_approve_friend_tags
  BEFORE INSERT ON post_tags
  FOR EACH ROW
  EXECUTE FUNCTION auto_approve_friend_tags();

-- 7. Function to enforce max 15 tags per post
CREATE OR REPLACE FUNCTION check_max_tags()
RETURNS TRIGGER AS $$
DECLARE
  tag_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO tag_count
  FROM post_tags
  WHERE post_id = NEW.post_id;
  
  IF tag_count >= 15 THEN
    RAISE EXCEPTION 'Maximum of 15 tags allowed per post';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 8. Trigger to enforce max tags
DROP TRIGGER IF EXISTS trigger_check_max_tags ON post_tags;
CREATE TRIGGER trigger_check_max_tags
  BEFORE INSERT ON post_tags
  FOR EACH ROW
  EXECUTE FUNCTION check_max_tags();

-- ============================================
-- VERIFICATION QUERIES (run after applying)
-- ============================================

-- Check table exists
-- SELECT * FROM post_tags LIMIT 1;

-- Check policies
-- SELECT policyname FROM pg_policies WHERE tablename = 'post_tags';

-- Check triggers
-- SELECT tgname FROM pg_trigger WHERE tgrelid = 'post_tags'::regclass;

-- ============================================
-- SUCCESS! Apply this SQL then confirm to proceed
-- ============================================
