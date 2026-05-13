-- Group Chat for Playdates Migration
-- Run this in Supabase SQL Editor

-- 1. Add group chat columns to conversations table
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS is_group BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS playdate_id UUID REFERENCES playdates(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS group_name TEXT;

-- 2. Create conversation_participants table for group members
CREATE TABLE IF NOT EXISTS conversation_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member', -- 'admin', 'member'
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(conversation_id, user_id)
);

-- 3. Add is_system_message to messages table
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS is_system_message BOOLEAN DEFAULT false;

-- 4. Create indexes
CREATE INDEX IF NOT EXISTS idx_conv_participants_conv ON conversation_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conv_participants_user ON conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_playdate ON conversations(playdate_id);
CREATE INDEX IF NOT EXISTS idx_conversations_is_group ON conversations(is_group);

-- 5. RLS Policies for conversation_participants
ALTER TABLE conversation_participants ENABLE ROW LEVEL SECURITY;

-- Users can view participants of conversations they're in
CREATE POLICY "Users can view participants of their conversations" ON conversation_participants
  FOR SELECT USING (
    user_id = auth.uid() OR 
    conversation_id IN (
      SELECT conversation_id FROM conversation_participants WHERE user_id = auth.uid()
    )
  );

-- Users can insert themselves into conversations (when joining)
CREATE POLICY "Users can join conversations" ON conversation_participants
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Admins can manage participants
CREATE POLICY "Admins can manage participants" ON conversation_participants
  FOR ALL USING (
    conversation_id IN (
      SELECT conversation_id FROM conversation_participants 
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
