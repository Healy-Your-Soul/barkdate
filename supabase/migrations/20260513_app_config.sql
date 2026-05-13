-- Table to store app-wide configuration and update information
CREATE TABLE IF NOT EXISTS public.app_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Insert initial update configuration
INSERT INTO public.app_config (key, value, description)
VALUES (
    'update_config',
    '{
        "latest_version": "1.0.0",
        "min_required_version": "1.0.0",
        "android_url": "https://barkdate.app/download/android",
        "ios_url": "https://barkdate.app/download/ios",
        "message": "A new version of BarkDate is available! Update now to get the latest features and fixes."
    }'::jsonb,
    'Configuration for app updates'
) ON CONFLICT (key) DO NOTHING;

-- RLS Policies
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read app_config
CREATE POLICY "Allow public read app_config" ON public.app_config
    FOR SELECT USING (true);
