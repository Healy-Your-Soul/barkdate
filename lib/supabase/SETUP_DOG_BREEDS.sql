-- ============================================
-- SETUP DOG BREEDS TABLE
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Create table
CREATE TABLE IF NOT EXISTS dog_breeds (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT GENERATED ALWAYS AS (lower(trim(name))) STORED, -- specific for search
    status TEXT DEFAULT 'approved' CHECK (status IN ('approved', 'pending')),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE dog_breeds ENABLE ROW LEVEL SECURITY;

-- 3. Create Policies

-- Anyone can read approved breeds
CREATE POLICY "Anyone can read approved breeds" ON dog_breeds
    FOR SELECT USING (status = 'approved');

-- Authenticated users can insert (status will default to pending/approved depending on logic, 
-- ideally trigger or app logic sets it. Let's force pending for non-admins via trigger later, 
-- but for now allow insert).
CREATE POLICY "Authenticated users can insert breeds" ON dog_breeds
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow reading pending breeds if you created them (so you can see your own submission)
CREATE POLICY "Creators can read their pending breeds" ON dog_breeds
    FOR SELECT USING (auth.uid() = created_by);

-- 4. Grant Permissions
GRANT ALL ON dog_breeds TO authenticated;
GRANT SELECT ON dog_breeds TO anon;

-- 5. Seed Data (Top common breeds)
INSERT INTO dog_breeds (name, status) VALUES
('Mixed Breed', 'approved'),
('Labrador Retriever', 'approved'),
('French Bulldog', 'approved'),
('Golden Retriever', 'approved'),
('German Shepherd', 'approved'),
('Poodle', 'approved'),
('Bulldog', 'approved'),
('Beagle', 'approved'),
('Rottweiler', 'approved'),
('Dachshund', 'approved'),
('Corgi', 'approved'),
('Australian Shepherd', 'approved'),
('Yorkshire Terrier', 'approved'),
('Boxer', 'approved'),
('Great Dane', 'approved'),
('Siberian Husky', 'approved'),
('Cavalier King Charles Spaniel', 'approved'),
('Doberman Pinscher', 'approved'),
('Miniature Schnauzer', 'approved'),
('Shih Tzu', 'approved'),
('Boston Terrier', 'approved'),
('Bernese Mountain Dog', 'approved'),
('Pomeranian', 'approved'),
('Havanese', 'approved'),
('Cane Corso', 'approved'),
('English Springer Spaniel', 'approved'),
('Shetland Sheepdog', 'approved'),
('Brittany', 'approved'),
('Pug', 'approved'),
('Cocker Spaniel', 'approved'),
('Border Collie', 'approved'),
('Mastiff', 'approved'),
('Chihuahua', 'approved'),
('Vizsla', 'approved'),
('Basset Hound', 'approved'),
('Belgian Malinois', 'approved'),
('Maltese', 'approved'),
('Weimaraner', 'approved'),
('Collie', 'approved'),
('Newfoundland', 'approved'),
('Rhodesian Ridgeback', 'approved'),
('Shiba Inu', 'approved'),
('West Highland White Terrier', 'approved'),
('Bichon Frise', 'approved'),
('Bloodhound', 'approved'),
('Akita', 'approved'),
('St. Bernard', 'approved')
ON CONFLICT (name) DO NOTHING;

-- 6. Indexes
CREATE INDEX IF NOT EXISTS idx_dog_breeds_name ON dog_breeds(name);
CREATE INDEX IF NOT EXISTS idx_dog_breeds_slug ON dog_breeds(slug);
CREATE INDEX IF NOT EXISTS idx_dog_breeds_status ON dog_breeds(status);
