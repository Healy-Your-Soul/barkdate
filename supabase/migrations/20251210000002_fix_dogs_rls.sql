-- Fix RLS policy for dogs table UPDATE
-- This ensures users can update is_active (soft delete) on their own dogs

-- Drop existing update policy if it exists
DROP POLICY IF EXISTS "Users can update their own dogs" ON dogs;

-- Recreate with proper WITH CHECK clause
CREATE POLICY "Users can update their own dogs" ON dogs
  FOR UPDATE 
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Verify RLS is enabled
ALTER TABLE dogs ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT UPDATE ON dogs TO authenticated;
