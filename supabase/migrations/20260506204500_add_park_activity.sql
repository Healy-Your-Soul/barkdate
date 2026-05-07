-- 1. Add is_superadmin to users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_superadmin BOOLEAN DEFAULT FALSE;

-- 2. Create park_activity_reports table
CREATE TABLE IF NOT EXISTS public.park_activity_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    park_id TEXT NOT NULL,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    dog_count INTEGER NOT NULL DEFAULT 1,
    is_admin_override BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + interval '2 hours')
);

-- Indexes for fast querying by park and expiration
CREATE INDEX IF NOT EXISTS idx_park_activity_park_id ON public.park_activity_reports(park_id);
CREATE INDEX IF NOT EXISTS idx_park_activity_expires_at ON public.park_activity_reports(expires_at);

-- Set up Row Level Security (RLS)
ALTER TABLE public.park_activity_reports ENABLE ROW LEVEL SECURITY;

-- Anyone can read active park activity
CREATE POLICY "Anyone can view active park activity"
    ON public.park_activity_reports FOR SELECT
    USING (expires_at > NOW());

-- Authenticated users can insert their own reports
CREATE POLICY "Users can report park activity"
    ON public.park_activity_reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

-- 3. Create RPC function to get active parks
-- This returns the highest dog count per park_id that is currently active.
CREATE OR REPLACE FUNCTION get_active_parks()
RETURNS TABLE (
    park_id TEXT,
    dog_count INTEGER,
    latest_report_time TIMESTAMP WITH TIME ZONE
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        park_id,
        MAX(dog_count)::INTEGER as dog_count,
        MAX(created_at) as latest_report_time
    FROM public.park_activity_reports
    WHERE expires_at > NOW()
    GROUP BY park_id;
$$;
