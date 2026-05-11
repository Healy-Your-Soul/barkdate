-- Use latest report per park instead of max(dog_count)
CREATE OR REPLACE FUNCTION get_active_parks()
RETURNS TABLE (
    park_id TEXT,
    dog_count INTEGER,
    latest_report_time TIMESTAMP WITH TIME ZONE
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT DISTINCT ON (park_id)
        park_id,
        dog_count,
        created_at AS latest_report_time
    FROM public.park_activity_reports
    WHERE expires_at > NOW()
    ORDER BY park_id, created_at DESC;
$$;
