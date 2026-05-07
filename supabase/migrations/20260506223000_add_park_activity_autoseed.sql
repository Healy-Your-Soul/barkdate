-- Add source column for activity provenance
ALTER TABLE public.park_activity_reports
ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'user';

-- Log auto-seed runs per area per day
CREATE TABLE IF NOT EXISTS public.park_activity_seed_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    area_key TEXT NOT NULL,
    seeded_on DATE NOT NULL,
    seeded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    seeded_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_park_activity_seed_log_area_day
    ON public.park_activity_seed_log(area_key, seeded_on);

ALTER TABLE public.park_activity_seed_log ENABLE ROW LEVEL SECURITY;

-- Only service role or authenticated users can insert seed logs
CREATE POLICY "Seed log insert"
    ON public.park_activity_seed_log FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = seeded_by);

-- No direct selects for clients
CREATE POLICY "Seed log no read"
    ON public.park_activity_seed_log FOR SELECT
    USING (false);

-- Auto-seed function: inserts reports only if area not seeded today
CREATE OR REPLACE FUNCTION public.auto_seed_park_activity(
    p_area_key TEXT,
    p_park_ids TEXT[],
    p_dog_counts INTEGER[]
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    today DATE := CURRENT_DATE;
BEGIN
    IF array_length(p_park_ids, 1) IS NULL OR array_length(p_dog_counts, 1) IS NULL THEN
        RETURN FALSE;
    END IF;

    IF array_length(p_park_ids, 1) <> array_length(p_dog_counts, 1) THEN
        RAISE EXCEPTION 'park_ids and dog_counts length mismatch';
    END IF;

    -- Skip if any active reports exist in this area already
    IF EXISTS (
        SELECT 1
        FROM public.park_activity_reports
        WHERE park_id = ANY(p_park_ids)
          AND expires_at > NOW()
    ) THEN
        RETURN FALSE;
    END IF;

    BEGIN
        INSERT INTO public.park_activity_seed_log(area_key, seeded_on, seeded_by)
        VALUES (p_area_key, today, auth.uid());
    EXCEPTION WHEN unique_violation THEN
        RETURN FALSE;
    END;

    INSERT INTO public.park_activity_reports (
        park_id,
        reporter_id,
        dog_count,
        is_admin_override,
        source
    )
    SELECT p_park_ids[i], auth.uid(), p_dog_counts[i], TRUE, 'auto_seed'
    FROM generate_subscripts(p_park_ids, 1) AS s(i);

    RETURN TRUE;
END;
$$;
