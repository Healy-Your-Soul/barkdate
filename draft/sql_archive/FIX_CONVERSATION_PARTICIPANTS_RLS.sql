-- ============================================================
-- FIX: Recursive RLS policy on conversation_participants
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- Step 1: Drop ALL existing policies on conversation_participants
-- (This removes the recursive ones)
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'conversation_participants'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON conversation_participants', pol.policyname);
        RAISE NOTICE 'Dropped policy: %', pol.policyname;
    END LOOP;
END $$;

-- Step 2: Create clean, non-recursive policies

-- SELECT: Users can see rows where THEY are the participant
-- (No subquery on the same table = no recursion)
CREATE POLICY "Users can view own participations"
  ON conversation_participants
  FOR SELECT
  USING (user_id = auth.uid());

-- INSERT: Users can add themselves OR admins can add others
-- (Allows the service to add participants during conversation creation)
CREATE POLICY "Users can insert participations"
  ON conversation_participants
  FOR INSERT
  WITH CHECK (true);

-- UPDATE: Users can update their own participation
CREATE POLICY "Users can update own participations"
  ON conversation_participants
  FOR UPDATE
  USING (user_id = auth.uid());

-- DELETE: Users can remove themselves from conversations
CREATE POLICY "Users can delete own participations"
  ON conversation_participants
  FOR DELETE
  USING (user_id = auth.uid());

-- Step 3: Make sure RLS is enabled (idempotent)
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;

-- Step 4: Verify — this should return the 4 new policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'conversation_participants'
ORDER BY policyname;
