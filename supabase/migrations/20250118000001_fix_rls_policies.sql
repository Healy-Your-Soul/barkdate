-- Safe RLS policy fixes
-- This will update policies without breaking existing ones

-- Fix notifications table policies (currently getting 403 errors)
-- Drop existing policies first to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications for others" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Service role can manage all notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

-- Enable RLS on notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own notifications
CREATE POLICY "Users can view their own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Allow authenticated users to create notifications for others (needed for playdate invites)
CREATE POLICY "Authenticated users can create notifications" ON notifications
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Allow users to update their own notifications (mark as read)
CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Allow users to delete their own notifications
CREATE POLICY "Users can delete their own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

-- Fix event_participants table policies
DROP POLICY IF EXISTS "Users can view event participants" ON event_participants;
DROP POLICY IF EXISTS "Users can join events" ON event_participants;
DROP POLICY IF EXISTS "Users can leave events" ON event_participants;
DROP POLICY IF EXISTS "Anyone can view event participants" ON event_participants;
DROP POLICY IF EXISTS "Authenticated users can join events" ON event_participants;
DROP POLICY IF EXISTS "Users can update their participation" ON event_participants;

-- Enable RLS on event_participants table
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;

-- Allow anyone to view event participants
CREATE POLICY "Anyone can view event participants" ON event_participants
    FOR SELECT USING (true);

-- Allow authenticated users to join events
CREATE POLICY "Authenticated users can join events" ON event_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own participation
CREATE POLICY "Users can update their participation" ON event_participants
    FOR UPDATE USING (auth.uid() = user_id);

-- Allow users to leave events (delete their participation)
CREATE POLICY "Users can leave events" ON event_participants
    FOR DELETE USING (auth.uid() = user_id);

-- Fix dog_friendships table policies for ambiguous relationships
DROP POLICY IF EXISTS "Users can view friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Users can create friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Users can view their dogs friendships" ON dog_friendships;
DROP POLICY IF EXISTS "Users can create friendships for their dogs" ON dog_friendships;
DROP POLICY IF EXISTS "Users can delete their dogs friendships" ON dog_friendships;

-- Enable RLS on dog_friendships table
ALTER TABLE dog_friendships ENABLE ROW LEVEL SECURITY;

-- Allow users to view friendships involving their dogs
CREATE POLICY "Users can view their dogs friendships" ON dog_friendships
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM dogs 
            WHERE dogs.id IN (dog1_id, dog2_id) 
            AND dogs.user_id = auth.uid()
        )
    );

-- Allow users to create friendships for their dogs
CREATE POLICY "Users can create friendships for their dogs" ON dog_friendships
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM dogs 
            WHERE dogs.id IN (dog1_id, dog2_id) 
            AND dogs.user_id = auth.uid()
        )
    );

-- Allow users to delete friendships for their dogs
CREATE POLICY "Users can delete their dogs friendships" ON dog_friendships
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM dogs 
            WHERE dogs.id IN (dog1_id, dog2_id) 
            AND dogs.user_id = auth.uid()
        )
    );
