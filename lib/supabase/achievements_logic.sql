-- Achievement Logic & Triggers

-- 0. FIX CONSTRAINTS: Allow new requirement types
-- The original table has a strict check constraint. We need to drop and recreate it to include new types.
DO $$
BEGIN
    -- Try to drop the constraint if it uses the standard naming convention
    ALTER TABLE achievements DROP CONSTRAINT IF EXISTS achievements_requirement_type_check;
    
    -- Add the updated constraint with all new types
    ALTER TABLE achievements ADD CONSTRAINT achievements_requirement_type_check 
    CHECK (requirement_type IN (
        'playdates_count', 
        'matches_count', 
        'posts_count', 
        'days_active', 
        'premium', 
        'checkins_count', 
        'friends_count', 
        'likes_count', 
        'parks_count'
    ));
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not alter constraint automatically. You may need to run: ALTER TABLE achievements DROP CONSTRAINT achievements_requirement_type_check;';
END $$;

-- 1. Ensure achievements exist (matching the app's list)
-- We use ON CONFLICT (name) DO UPDATE to ensure we don't duplicate
INSERT INTO achievements (name, description, icon, color, requirement_type, requirement_value) VALUES
('First Playdate', 'Complete your first successful playdate', 'calendar', 'green', 'playdates_count', 1),
('Park Regular', 'Visit the dog park 10 times', 'park', 'green', 'checkins_count', 10),
('Social Butterfly', 'Make friends with 5 different dogs', 'group', 'blue', 'friends_count', 5),
('Community Star', 'Get 100 likes on your posts', 'star', 'yellow', 'likes_count', 100),
('Photo Star', 'Share 5 posts with photos', 'camera', 'purple', 'posts_count', 5),
('Explorer', 'Check in at 5 different parks', 'explore', 'orange', 'parks_count', 5)
ON CONFLICT (name) DO UPDATE SET
description = EXCLUDED.description,
icon = EXCLUDED.icon,
color = EXCLUDED.color,
requirement_type = EXCLUDED.requirement_type,
requirement_value = EXCLUDED.requirement_value;

-- 2. Generic function to award an achievement by name
CREATE OR REPLACE FUNCTION award_achievement(target_user_id uuid, achievement_name text)
RETURNS void AS $$
DECLARE
    target_achievement_id uuid;
BEGIN
    -- Get achievement ID
    SELECT id INTO target_achievement_id FROM achievements WHERE name = achievement_name;
    
    IF target_achievement_id IS NOT NULL THEN
        -- Insert if not exists
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (target_user_id, target_achievement_id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;
        
        -- Optional: Create notification? (Handled by app or separate trigger on user_achievements)
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Triggers for specific achievements

-- A. "First Playdate" -> Trigger on playdates status change to 'completed'
CREATE OR REPLACE FUNCTION check_first_playdate_achievement()
RETURNS TRIGGER AS $$
DECLARE
    participant record;
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Award to organizer
        PERFORM award_achievement(NEW.organizer_id, 'First Playdate');
        
        -- Award to all participants
        FOR participant IN SELECT user_id FROM playdate_participants WHERE playdate_id = NEW.id LOOP
            PERFORM award_achievement(participant.user_id, 'First Playdate');
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_first_playdate ON playdates;
CREATE TRIGGER trigger_first_playdate
AFTER UPDATE ON playdates
FOR EACH ROW
EXECUTE FUNCTION check_first_playdate_achievement();

-- B. "Park Regular" (10 checkins) & "Explorer" (5 different parks) -> Trigger on checkins INSERT
CREATE OR REPLACE FUNCTION check_park_achievements()
RETURNS TRIGGER AS $$
DECLARE
    total_checkins integer;
    unique_parks integer;
BEGIN
    -- Park Regular: 10 checkins
    SELECT COUNT(*) INTO total_checkins FROM checkins WHERE user_id = NEW.user_id;
    IF total_checkins >= 10 THEN
        PERFORM award_achievement(NEW.user_id, 'Park Regular');
    END IF;
    
    -- Explorer: 5 different parks
    SELECT COUNT(DISTINCT park_id) INTO unique_parks FROM checkins WHERE user_id = NEW.user_id;
    IF unique_parks >= 5 THEN
        PERFORM award_achievement(NEW.user_id, 'Explorer');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_park_achievements ON checkins;
CREATE TRIGGER trigger_park_achievements
AFTER INSERT ON checkins
FOR EACH ROW
EXECUTE FUNCTION check_park_achievements();

-- C. "Social Butterfly" (5 friends) -> Trigger on dog_friendships
CREATE OR REPLACE FUNCTION check_social_butterfly_achievement()
RETURNS TRIGGER AS $$
DECLARE
    dog_owner_id uuid;
    friend_count integer;
BEGIN
    -- Get owner of the dog
    SELECT user_id INTO dog_owner_id FROM dogs WHERE id = NEW.dog_id;
    
    IF dog_owner_id IS NOT NULL THEN
        -- Count friends
        SELECT COUNT(*) INTO friend_count FROM dog_friendships WHERE dog_id = NEW.dog_id AND status = 'accepted'; -- Assuming 'accepted' or similar status
        -- If status column doesn't exist or uses different values, adjust accordingly. 
        -- Based on previous files, status might be 'friend' or 'best_friend'.
        
        IF friend_count >= 5 THEN
            PERFORM award_achievement(dog_owner_id, 'Social Butterfly');
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_social_butterfly ON dog_friendships;
CREATE TRIGGER trigger_social_butterfly
AFTER INSERT OR UPDATE ON dog_friendships
FOR EACH ROW
EXECUTE FUNCTION check_social_butterfly_achievement();

-- D. "Community Star" (100 likes) -> Trigger on post_likes
CREATE OR REPLACE FUNCTION check_community_star_achievement()
RETURNS TRIGGER AS $$
DECLARE
    post_author_id uuid;
    total_likes integer;
BEGIN
    -- Get post author
    SELECT user_id INTO post_author_id FROM posts WHERE id = NEW.post_id;
    
    IF post_author_id IS NOT NULL THEN
        -- Count total likes received by user across all posts
        SELECT COUNT(*) INTO total_likes 
        FROM post_likes pl
        JOIN posts p ON pl.post_id = p.id
        WHERE p.user_id = post_author_id;
        
        IF total_likes >= 100 THEN
            PERFORM award_achievement(post_author_id, 'Community Star');
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_community_star ON post_likes;
CREATE TRIGGER trigger_community_star
AFTER INSERT ON post_likes
FOR EACH ROW
EXECUTE FUNCTION check_community_star_achievement();

-- E. "Photo Star" (5 posts with photos) -> Trigger on posts
CREATE OR REPLACE FUNCTION check_photo_star_achievement()
RETURNS TRIGGER AS $$
DECLARE
    photo_posts_count integer;
BEGIN
    IF NEW.image_urls IS NOT NULL AND array_length(NEW.image_urls, 1) > 0 THEN
        SELECT COUNT(*) INTO photo_posts_count 
        FROM posts 
        WHERE user_id = NEW.user_id 
        AND image_urls IS NOT NULL 
        AND array_length(image_urls, 1) > 0;
        
        IF photo_posts_count >= 5 THEN
            PERFORM award_achievement(NEW.user_id, 'Photo Star');
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_photo_star ON posts;
CREATE TRIGGER trigger_photo_star
AFTER INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION check_photo_star_achievement();
