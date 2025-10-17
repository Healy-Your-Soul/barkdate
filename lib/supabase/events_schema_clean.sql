-- Events Database Schema for BarkDate (Clean Install)
-- This script safely drops and recreates the events feature

-- Drop existing indexes first (if they exist)
DROP INDEX IF EXISTS idx_events_organizer_id;
DROP INDEX IF EXISTS idx_events_status;
DROP INDEX IF EXISTS idx_events_start_time;
DROP INDEX IF EXISTS idx_events_category;
DROP INDEX IF EXISTS idx_events_location;
DROP INDEX IF EXISTS idx_event_participants_event_id;
DROP INDEX IF EXISTS idx_event_participants_user_id;

-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS events_updated_at ON events;
DROP FUNCTION IF EXISTS update_events_updated_at();
DROP FUNCTION IF EXISTS increment_event_participants(uuid);
DROP FUNCTION IF EXISTS decrement_event_participants(uuid);

-- Drop existing tables (if they exist)
DROP TABLE IF EXISTS event_participants CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS event_categories CASCADE;

-- Events table
CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  organizer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organizer_type text NOT NULL DEFAULT 'user' CHECK (organizer_type IN ('user', 'professional')),
  start_time timestamp with time zone NOT NULL,
  end_time timestamp with time zone NOT NULL,
  location text NOT NULL,
  latitude double precision,
  longitude double precision,
  category text NOT NULL CHECK (category IN ('birthday', 'training', 'social', 'professional')),
  max_participants integer NOT NULL DEFAULT 10,
  current_participants integer NOT NULL DEFAULT 0,
  target_age_groups text[] DEFAULT '{}', -- ['puppy', 'adult', 'senior']
  target_sizes text[] DEFAULT '{}', -- ['small', 'medium', 'large', 'extra large']
  price double precision DEFAULT 0, -- null for free events
  photo_urls text[] DEFAULT '{}',
  requires_registration boolean DEFAULT true,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Event participants (many-to-many relationship)
CREATE TABLE event_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  joined_at timestamp with time zone DEFAULT now(),
  UNIQUE(event_id, user_id, dog_id)
);

-- Event categories lookup table
CREATE TABLE event_categories (
  id text PRIMARY KEY,
  name text NOT NULL,
  icon text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX idx_events_organizer_id ON events(organizer_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_time ON events(start_time);
CREATE INDEX idx_events_category ON events(category);
CREATE INDEX idx_events_location ON events(location);
CREATE INDEX idx_event_participants_event_id ON event_participants(event_id);
CREATE INDEX idx_event_participants_user_id ON event_participants(user_id);

-- Function to increment event participants count
CREATE OR REPLACE FUNCTION increment_event_participants(event_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE events 
  SET current_participants = current_participants + 1,
      updated_at = now()
  WHERE id = event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement event participants count
CREATE OR REPLACE FUNCTION decrement_event_participants(event_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE events 
  SET current_participants = GREATEST(current_participants - 1, 0),
      updated_at = now()
  WHERE id = event_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_events_updated_at();

-- Enable Row Level Security
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_categories ENABLE ROW LEVEL SECURITY;

-- RLS Policies for events table
CREATE POLICY "Anyone can view events" ON events
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create events" ON events
  FOR INSERT WITH CHECK (auth.uid() = organizer_id);

CREATE POLICY "Organizers can update their events" ON events
  FOR UPDATE USING (auth.uid() = organizer_id);

CREATE POLICY "Organizers can delete their events" ON events
  FOR DELETE USING (auth.uid() = organizer_id);

-- RLS Policies for event_participants table
CREATE POLICY "Users can view their own participations" ON event_participants
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view event participants" ON event_participants
  FOR SELECT USING (true);

CREATE POLICY "Users can join events" ON event_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave events" ON event_participants
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for event_categories table
CREATE POLICY "Anyone can view event categories" ON event_categories
  FOR SELECT USING (true);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON events TO authenticated;
GRANT ALL ON event_participants TO authenticated;
GRANT SELECT ON event_categories TO authenticated;

-- Insert default event categories
INSERT INTO event_categories (id, name, icon, description) VALUES
('birthday', 'Birthday Party', '🎂', 'Celebrate your dog''s special day'),
('training', 'Training Class', '🎓', 'Learn new skills and behaviors'),
('social', 'Social Meetup', '🐕', 'Meet new friends and play'),
('professional', 'Professional Service', '🏥', 'Grooming, vet visits, and care');

-- Insert sample events for testing (optional - uncomment if needed)
/*
INSERT INTO events (title, description, organizer_id, start_time, end_time, location, category, max_participants, target_age_groups, target_sizes, price, status)
SELECT 
  'Puppy Playtime at Central Park',
  'Join us for an energetic play session designed specifically for puppies under 1 year old. Great for socialization!',
  u.id,
  now() + interval '2 days 10 hours',
  now() + interval '2 days 12 hours',
  'Central Park Dog Run',
  'social',
  15,
  ARRAY['puppy'],
  ARRAY['small', 'medium'],
  0,
  'upcoming'
FROM users u
LIMIT 1;
*/
