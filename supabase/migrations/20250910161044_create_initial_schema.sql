-- BarkDate Database Schema
-- Complete database schema for the dog social networking app

-- Users table (linked to auth.users) with Firebase integration
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  avatar_url text,
  bio text,
  location text,
  firebase_uid text, -- Firebase UID for seamless Firebase Auth integration
  is_premium boolean DEFAULT false,
  premium_expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Dogs table
CREATE TABLE dogs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  breed text NOT NULL,
  age integer NOT NULL,
  size text NOT NULL CHECK (size IN ('Small', 'Medium', 'Large', 'Extra Large')),
  gender text NOT NULL CHECK (gender IN ('Male', 'Female')),
  main_photo_url text, -- Primary/featured photo (center display)
  extra_photo_urls text[] DEFAULT '{}', -- Up to 3 additional photos
  photo_urls text[] DEFAULT '{}', -- All photos (backward compatibility)
  bio text,
  temperament text[] DEFAULT '{}',
  vaccinated boolean DEFAULT false,
  neutered boolean DEFAULT false,
  weight_kg integer,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Matches table (for Tinder-style matching)
CREATE TABLE matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  target_dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('bark', 'pass')),
  is_mutual boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id, target_user_id, dog_id, target_dog_id)
);

-- Messages table (for real-time messaging)
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  message_type text DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'playdate_request')),
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

-- Playdates table
CREATE TABLE playdates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  location text NOT NULL,
  latitude double precision,
  longitude double precision,
  scheduled_at timestamp with time zone NOT NULL,
  duration_minutes integer DEFAULT 60,
  max_dogs integer DEFAULT 2,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Playdate participants (many-to-many relationship)
CREATE TABLE playdate_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id uuid NOT NULL REFERENCES playdates(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES dogs(id) ON DELETE CASCADE,
  joined_at timestamp with time zone DEFAULT now(),
  UNIQUE(playdate_id, user_id, dog_id)
);

-- Posts table (for social feed)
CREATE TABLE posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dog_id uuid REFERENCES dogs(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_urls text[] DEFAULT '{}',
  location text,
  latitude double precision,
  longitude double precision,
  likes_count integer DEFAULT 0,
  comments_count integer DEFAULT 0,
  is_public boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Post likes
CREATE TABLE post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(post_id, user_id)
);

-- Post comments
CREATE TABLE post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Achievements table
CREATE TABLE achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  description text NOT NULL,
  icon text NOT NULL,
  color text NOT NULL,
  requirement_type text NOT NULL CHECK (requirement_type IN ('playdates_count', 'matches_count', 'posts_count', 'days_active', 'premium')),
  requirement_value integer NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- User achievements (earned badges)
CREATE TABLE user_achievements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id uuid NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at timestamp with time zone DEFAULT now(),
  UNIQUE(user_id, achievement_id)
);

-- Premium subscriptions
CREATE TABLE premium_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_type text NOT NULL CHECK (subscription_type IN ('monthly', 'yearly')),
  start_date timestamp with time zone DEFAULT now(),
  end_date timestamp with time zone NOT NULL,
  status text DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired')),
  payment_provider text,
  payment_id text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Notifications table
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  type text NOT NULL CHECK (type IN ('match', 'message', 'playdate', 'achievement', 'system')),
  data jsonb,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

-- Park locations for map feature
CREATE TABLE parks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  amenities text[] DEFAULT '{}',
  rating numeric(3,2) DEFAULT 0.0,
  photo_urls text[] DEFAULT '{}',
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX idx_dogs_user_id ON dogs(user_id);
CREATE INDEX idx_dogs_is_active ON dogs(is_active);
CREATE INDEX idx_matches_user_id ON matches(user_id);
CREATE INDEX idx_matches_target_user_id ON matches(target_user_id);
CREATE INDEX idx_matches_is_mutual ON matches(is_mutual);
CREATE INDEX idx_messages_match_id ON messages(match_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_playdates_scheduled_at ON playdates(scheduled_at);
CREATE INDEX idx_playdates_status ON playdates(status);
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_posts_is_public ON posts(is_public);
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_parks_location ON parks USING GIST(point(longitude, latitude));
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid); -- Index for Firebase UID lookups

-- Firebase Auth integration function
CREATE OR REPLACE FUNCTION sync_firebase_user_with_supabase(
    firebase_uid_param TEXT,
    user_email TEXT,
    user_name TEXT DEFAULT NULL,
    avatar_url TEXT DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_id uuid;
    auth_user_exists boolean;
BEGIN
    -- Check if we already have this user by firebase_uid
    SELECT id INTO user_id 
    FROM public.users 
    WHERE firebase_uid = firebase_uid_param;
    
    IF user_id IS NOT NULL THEN
        -- User already exists, update and return their ID
        UPDATE public.users 
        SET 
            name = COALESCE(user_name, public.users.name),
            avatar_url = COALESCE(sync_firebase_user_with_supabase.avatar_url, public.users.avatar_url),
            updated_at = NOW()
        WHERE firebase_uid = firebase_uid_param
        RETURNING id INTO user_id;
        
        RETURN user_id;
    END IF;
    
    -- Check if user exists by email
    SELECT id INTO user_id 
    FROM public.users 
    WHERE email = user_email;
    
    IF user_id IS NOT NULL THEN
        -- User exists by email, add firebase_uid
        UPDATE public.users 
        SET 
            firebase_uid = firebase_uid_param,
            name = COALESCE(user_name, public.users.name),
            avatar_url = COALESCE(sync_firebase_user_with_supabase.avatar_url, public.users.avatar_url),
            updated_at = NOW()
        WHERE email = user_email
        RETURNING id INTO user_id;
        
        RETURN user_id;
    END IF;
    
    -- Check if auth user exists for this email
    SELECT EXISTS(
        SELECT 1 FROM auth.users WHERE email = user_email
    ) INTO auth_user_exists;
    
    IF NOT auth_user_exists THEN
        -- Auth user doesn't exist, we can't create public user yet
        RAISE EXCEPTION 'Auth user with email % does not exist. Create auth user first.', user_email;
    END IF;
    
    -- Get the auth user ID
    SELECT id INTO user_id 
    FROM auth.users 
    WHERE email = user_email;
    
    -- Create the public user record using the auth user's ID
    INSERT INTO public.users (
        id, 
        email, 
        name, 
        avatar_url, 
        firebase_uid,
        created_at,
        updated_at
    ) VALUES (
        user_id,
        user_email,
        COALESCE(user_name, split_part(user_email, '@', 1)),
        avatar_url,
        firebase_uid_param,
        NOW(),
        NOW()
    )
    RETURNING id INTO user_id;
    
    RETURN user_id;
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Foreign key constraint violation: Auth user with email % must exist first', user_email;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error syncing Firebase user %: %', user_email, SQLERRM;
END;
$$;

-- Grant permissions for the sync function
GRANT EXECUTE ON FUNCTION sync_firebase_user_with_supabase TO authenticated;
GRANT EXECUTE ON FUNCTION sync_firebase_user_with_supabase TO anon;

-- Insert default achievements
INSERT INTO achievements (name, description, icon, color, requirement_type, requirement_value) VALUES
('First Match', 'Got your first bark match!', 'favorite', 'pink', 'matches_count', 1),
('Popular Pup', 'Received 10 bark matches', 'stars', 'yellow', 'matches_count', 10),
('Social Butterfly', 'Posted 5 adventures', 'camera', 'blue', 'posts_count', 5),
('Playdate Pro', 'Organized 3 successful playdates', 'pets', 'green', 'playdates_count', 3),
('Premium Member', 'Upgraded to premium features', 'diamond', 'purple', 'premium', 1),
('Community Leader', 'Posted 25 adventures', 'trophy', 'orange', 'posts_count', 25),
('Super Social', 'Got 50 bark matches', 'celebration', 'red', 'matches_count', 50);
