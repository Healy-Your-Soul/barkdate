-- BarkDate Security Policies
-- Row Level Security policies for all tables

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE dogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdates ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdate_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE premium_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE parks ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" ON users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (true);

CREATE POLICY "Users can delete their own profile" ON users
  FOR DELETE USING (auth.uid() = id);

-- Dogs table policies
CREATE POLICY "Authenticated users can view all dogs" ON dogs
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert dogs for themselves" ON dogs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own dogs" ON dogs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own dogs" ON dogs
  FOR DELETE USING (auth.uid() = user_id);

-- Matches table policies
CREATE POLICY "Users can view their matches" ON matches
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = target_user_id);

CREATE POLICY "Users can create matches" ON matches
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their matches" ON matches
  FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = target_user_id);

CREATE POLICY "Users can delete their matches" ON matches
  FOR DELETE USING (auth.uid() = user_id);

-- Messages table policies
CREATE POLICY "Users can view their messages" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their messages" ON messages
  FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can delete their sent messages" ON messages
  FOR DELETE USING (auth.uid() = sender_id);

-- Playdates table policies
CREATE POLICY "Users can view playdates they're involved in" ON playdates
  FOR SELECT USING (auth.uid() = organizer_id OR auth.uid() = participant_id);

CREATE POLICY "Users can create playdates" ON playdates
  FOR INSERT WITH CHECK (auth.uid() = organizer_id);

CREATE POLICY "Users can update playdates they organize" ON playdates
  FOR UPDATE USING (auth.uid() = organizer_id);

CREATE POLICY "Users can delete playdates they organize" ON playdates
  FOR DELETE USING (auth.uid() = organizer_id);

-- Playdate participants policies
CREATE POLICY "Users can view playdate participants" ON playdate_participants
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can join playdates" ON playdate_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their participation" ON playdate_participants
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can leave playdates" ON playdate_participants
  FOR DELETE USING (auth.uid() = user_id);

-- Posts table policies
CREATE POLICY "Authenticated users can view public posts" ON posts
  FOR SELECT USING (is_public = true AND auth.role() = 'authenticated');

CREATE POLICY "Users can view their own posts" ON posts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own posts" ON posts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own posts" ON posts
  FOR DELETE USING (auth.uid() = user_id);

-- Post likes policies
CREATE POLICY "Authenticated users can view post likes" ON post_likes
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can like posts" ON post_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike posts" ON post_likes
  FOR DELETE USING (auth.uid() = user_id);

-- Post comments policies
CREATE POLICY "Authenticated users can view comments" ON post_comments
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can comment on posts" ON post_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their comments" ON post_comments
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their comments" ON post_comments
  FOR DELETE USING (auth.uid() = user_id);

-- Achievements table policies (read-only for users)
CREATE POLICY "Authenticated users can view achievements" ON achievements
  FOR SELECT USING (auth.role() = 'authenticated');

-- User achievements policies
CREATE POLICY "Users can view their achievements" ON user_achievements
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can award achievements" ON user_achievements
  FOR INSERT WITH CHECK (true);

-- Premium subscriptions policies
CREATE POLICY "Users can view their subscriptions" ON premium_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create subscriptions" ON premium_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their subscriptions" ON premium_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Users can view their notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can create notifications" ON notifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update their notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their notifications" ON notifications
  FOR DELETE USING (auth.uid() = user_id);

-- Parks table policies (read-only for users)
CREATE POLICY "Authenticated users can view parks" ON parks
  FOR SELECT USING (auth.role() = 'authenticated');