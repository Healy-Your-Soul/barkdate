-- Add featured_parks table for enhanced park management
-- This extends the basic parks table with admin-curated features

CREATE TABLE featured_parks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  amenities text[] DEFAULT '{}',
  address text,
  rating numeric(3,2) DEFAULT 0.0,
  review_count integer DEFAULT 0,
  photo_urls text[] DEFAULT '{}',
  is_active boolean DEFAULT true,
  featured_since timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Add admin table for park management
CREATE TABLE park_admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  can_add_parks boolean DEFAULT false,
  can_edit_parks boolean DEFAULT false,
  can_feature_parks boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id)
);

-- Add park check-ins for real-time presence
CREATE TABLE park_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id uuid REFERENCES parks(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid REFERENCES dogs(id) ON DELETE CASCADE,
  latitude double precision,
  longitude double precision,
  checked_in_at timestamp with time zone DEFAULT now(),
  checked_out_at timestamp with time zone,
  is_active boolean DEFAULT true
);

-- Create indexes for performance
CREATE INDEX idx_featured_parks_location ON featured_parks USING GIST(point(longitude, latitude));
CREATE INDEX idx_featured_parks_is_active ON featured_parks(is_active);
CREATE INDEX idx_featured_parks_rating ON featured_parks(rating DESC);
CREATE INDEX idx_park_checkins_park_id ON park_checkins(park_id);
CREATE INDEX idx_park_checkins_user_id ON park_checkins(user_id);
CREATE INDEX idx_park_checkins_is_active ON park_checkins(is_active);
CREATE INDEX idx_park_checkins_checked_in_at ON park_checkins(checked_in_at DESC);

-- Enable RLS
ALTER TABLE featured_parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_checkins ENABLE ROW LEVEL SECURITY;

-- RLS Policies for featured_parks
CREATE POLICY "Everyone can view featured parks" ON featured_parks
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "Admins can insert featured parks" ON featured_parks
  FOR INSERT TO authenticated 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM park_admins 
      WHERE user_id = auth.uid() AND can_add_parks = true
    )
  );

CREATE POLICY "Admins can update featured parks" ON featured_parks
  FOR UPDATE TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM park_admins 
      WHERE user_id = auth.uid() AND can_edit_parks = true
    )
  );

-- RLS Policies for park_admins
CREATE POLICY "Users can view their admin status" ON park_admins
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- RLS Policies for park_checkins  
CREATE POLICY "Users can view all active checkins" ON park_checkins
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY "Users can manage their own checkins" ON park_checkins
  FOR ALL TO authenticated USING (user_id = auth.uid());

-- Insert sample featured parks
INSERT INTO featured_parks (name, description, latitude, longitude, amenities, address, rating, review_count, photo_urls) VALUES
('Central Bark Dog Park', 'Large off-leash area with separate sections for small and large dogs. Features agility equipment and water fountains.', 40.7829, -73.9654, ARRAY['off-leash', 'agility', 'water', 'parking', 'shade'], '1234 Park Ave, New York, NY 10128', 4.5, 127, ARRAY['https://example.com/central-bark-1.jpg', 'https://example.com/central-bark-2.jpg']),
('Riverside Dog Run', 'Scenic waterfront dog park with sandy area and river access. Perfect for dogs who love to swim.', 40.7489, -73.9857, ARRAY['off-leash', 'water-access', 'sand', 'scenic'], '567 Riverside Dr, New York, NY 10025', 4.3, 89, ARRAY['https://example.com/riverside-1.jpg']),
('Sunset Hills Dog Park', 'Spacious hilltop park with panoramic city views. Great for hiking with your dog.', 40.7505, -73.9934, ARRAY['hiking-trails', 'scenic', 'large-area'], '890 Sunset Blvd, New York, NY 10025', 4.7, 203, ARRAY['https://example.com/sunset-hills-1.jpg', 'https://example.com/sunset-hills-2.jpg', 'https://example.com/sunset-hills-3.jpg']),
('Metro Pooch Playground', 'Urban dog park with modern amenities and training areas. Located in the heart of downtown.', 40.7614, -73.9776, ARRAY['training-area', 'modern', 'urban', 'parking'], '123 Metro St, New York, NY 10019', 4.1, 64, ARRAY['https://example.com/metro-pooch-1.jpg']);

-- Make the current user an admin for testing (replace with actual user ID)
-- INSERT INTO park_admins (user_id, can_add_parks, can_edit_parks, can_feature_parks) 
-- VALUES ('6b0fdff3-b44d-4385-b961-a77223251251', true, true, true);
