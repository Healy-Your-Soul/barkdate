-- ============================================
-- IMPORTANT: Run this SQL in your Supabase SQL Editor
-- Go to: https://supabase.com/dashboard/project/caottaawpnocywayjmyl/sql/new
-- Copy and paste this entire file, then click "Run"
-- ============================================

-- Create playdate_participants table if it doesn't exist
CREATE TABLE IF NOT EXISTS playdate_participants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    playdate_id UUID REFERENCES playdates(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(playdate_id, user_id, dog_id)
);

-- Create playdate_requests table if it doesn't exist  
CREATE TABLE IF NOT EXISTS playdate_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    playdate_id UUID REFERENCES playdates(id) ON DELETE CASCADE,
    requester_id UUID REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID REFERENCES users(id) ON DELETE CASCADE,
    invitee_dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'counter_proposed')),
    message TEXT,
    counter_proposal JSONB,
    responded_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create playdate_recaps table if it doesn't exist
CREATE TABLE IF NOT EXISTS playdate_recaps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    playdate_id UUID REFERENCES playdates(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    dog_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
    experience_rating INTEGER CHECK (experience_rating >= 1 AND experience_rating <= 5),
    location_rating INTEGER CHECK (location_rating >= 1 AND location_rating <= 5),
    recap_text TEXT,
    photos TEXT[],
    shared_to_feed BOOLEAN DEFAULT false,
    post_id UUID REFERENCES posts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create dog_friendships table if it doesn't exist
CREATE TABLE IF NOT EXISTS dog_friendships (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    dog1_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
    dog2_id UUID REFERENCES dogs(id) ON DELETE CASCADE,
    formed_through_playdate_id UUID REFERENCES playdates(id) ON DELETE SET NULL,
    friendship_level TEXT DEFAULT 'acquaintance' CHECK (friendship_level IN ('acquaintance', 'friend', 'best_friend')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(dog1_id, dog2_id),
    CHECK (dog1_id < dog2_id) -- Ensure consistent ordering
);

-- Add missing columns to matches table if they don't exist
DO $$ 
BEGIN
    -- Add bark_count column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'matches' AND column_name = 'bark_count') THEN
        ALTER TABLE matches ADD COLUMN bark_count INTEGER DEFAULT 0;
    END IF;
    
    -- Add last_bark_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'matches' AND column_name = 'last_bark_at') THEN
        ALTER TABLE matches ADD COLUMN last_bark_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add is_mutual column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'matches' AND column_name = 'is_mutual') THEN
        ALTER TABLE matches ADD COLUMN is_mutual BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add missing columns to notifications table if they don't exist
DO $$ 
BEGIN
    -- Add action_type column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'notifications' AND column_name = 'action_type') THEN
        ALTER TABLE notifications ADD COLUMN action_type TEXT;
    END IF;
    
    -- Add related_id column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'notifications' AND column_name = 'related_id') THEN
        ALTER TABLE notifications ADD COLUMN related_id TEXT;
    END IF;
    
    -- Add metadata column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'notifications' AND column_name = 'metadata') THEN
        ALTER TABLE notifications ADD COLUMN metadata JSONB;
    END IF;
END $$;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_playdate_participants_playdate ON playdate_participants(playdate_id);
CREATE INDEX IF NOT EXISTS idx_playdate_participants_user ON playdate_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_invitee ON playdate_requests(invitee_id);
CREATE INDEX IF NOT EXISTS idx_playdate_requests_status ON playdate_requests(status);
CREATE INDEX IF NOT EXISTS idx_dog_friendships_dogs ON dog_friendships(dog1_id, dog2_id);
CREATE INDEX IF NOT EXISTS idx_matches_mutual ON matches(is_mutual) WHERE is_mutual = true;
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- Enable Row Level Security (RLS) on new tables
ALTER TABLE playdate_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdate_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdate_recaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE dog_friendships ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for playdate_participants
CREATE POLICY "Users can view their own playdate participants" ON playdate_participants
    FOR SELECT USING (
        auth.uid() = user_id OR 
        auth.uid() IN (SELECT organizer_id FROM playdates WHERE id = playdate_id) OR
        auth.uid() IN (SELECT participant_id FROM playdates WHERE id = playdate_id)
    );

CREATE POLICY "Users can insert their own playdate participants" ON playdate_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create RLS policies for playdate_requests
CREATE POLICY "Users can view their own playdate requests" ON playdate_requests
    FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = invitee_id);

CREATE POLICY "Users can create playdate requests" ON playdate_requests
    FOR INSERT WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Invitees can update their playdate requests" ON playdate_requests
    FOR UPDATE USING (auth.uid() = invitee_id);

-- Create RLS policies for playdate_recaps
CREATE POLICY "Users can view playdate recaps" ON playdate_recaps
    FOR SELECT USING (
        shared_to_feed = true OR 
        auth.uid() = user_id OR
        auth.uid() IN (SELECT organizer_id FROM playdates WHERE id = playdate_id) OR
        auth.uid() IN (SELECT participant_id FROM playdates WHERE id = playdate_id)
    );

CREATE POLICY "Users can create their own recaps" ON playdate_recaps
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create RLS policies for dog_friendships
CREATE POLICY "Users can view friendships of their dogs" ON dog_friendships
    FOR SELECT USING (
        auth.uid() IN (SELECT user_id FROM dogs WHERE id = dog1_id) OR
        auth.uid() IN (SELECT user_id FROM dogs WHERE id = dog2_id)
    );

CREATE POLICY "Users can create friendships for their dogs" ON dog_friendships
    FOR INSERT WITH CHECK (
        auth.uid() IN (SELECT user_id FROM dogs WHERE id = dog1_id) OR
        auth.uid() IN (SELECT user_id FROM dogs WHERE id = dog2_id)
    );

-- Grant permissions to authenticated users
GRANT ALL ON playdate_participants TO authenticated;
GRANT ALL ON playdate_requests TO authenticated;
GRANT ALL ON playdate_recaps TO authenticated;
GRANT ALL ON dog_friendships TO authenticated;

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'All tables and columns have been successfully created/updated!';
END $$;