-- ============================================
-- Social Features Database Update
-- Run this AFTER the main APPLY_THIS_TO_SUPABASE.sql
-- ============================================

-- Add columns to posts table for playdate recaps and dog tagging
DO $$ 
BEGIN
    -- Add playdate_id column to posts if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'playdate_id') THEN
        ALTER TABLE posts ADD COLUMN playdate_id UUID REFERENCES playdates(id) ON DELETE SET NULL;
    END IF;
    
    -- Add tagged_dogs column to posts if it doesn't exist  
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'posts' AND column_name = 'tagged_dogs') THEN
        ALTER TABLE posts ADD COLUMN tagged_dogs UUID[] DEFAULT '{}';
    END IF;
END $$;

-- Create storage bucket for photos if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('photos', 'photos', true)
ON CONFLICT (id) DO NOTHING;

-- Set up storage policies for photos bucket
CREATE POLICY "Anyone can view photos" ON storage.objects
    FOR SELECT USING (bucket_id = 'photos');

CREATE POLICY "Authenticated users can upload photos" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'photos' AND 
        auth.uid() IS NOT NULL
    );

CREATE POLICY "Users can update their own photos" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'photos' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete their own photos" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'photos' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_posts_playdate ON posts(playdate_id) WHERE playdate_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_tagged_dogs ON posts USING GIN(tagged_dogs);

-- Create a view for posts with tagged dogs info
CREATE OR REPLACE VIEW posts_with_tags AS
SELECT 
    p.*,
    array_agg(
        jsonb_build_object(
            'dog_id', d.id,
            'dog_name', d.name,
            'dog_photo', d.main_photo_url,
            'owner_id', d.user_id
        )
    ) FILTER (WHERE d.id IS NOT NULL) as tagged_dogs_info
FROM posts p
LEFT JOIN LATERAL unnest(p.tagged_dogs) AS tag_id ON true
LEFT JOIN dogs d ON d.id = tag_id
GROUP BY p.id;

-- Grant permissions
GRANT SELECT ON posts_with_tags TO authenticated;

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'Social features have been successfully added!';
END $$;