-- Parks and Check-ins schema for Map MVP
-- Safe to run multiple times (IF NOT EXISTS guards)

-- Enable required extensions (PostGIS optional)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS postgis; -- optional for geo queries

-- parks table
CREATE TABLE IF NOT EXISTS public.parks (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  address text,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- park_checkins table
CREATE TABLE IF NOT EXISTS public.park_checkins (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  park_id uuid NOT NULL REFERENCES public.parks(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  dog_id uuid NOT NULL REFERENCES public.dogs(id) ON DELETE CASCADE,
  latitude double precision,
  longitude double precision,
  checked_in_at timestamptz NOT NULL DEFAULT now(),
  checked_out_at timestamptz,
  is_active boolean NOT NULL DEFAULT true
);

-- indexes
CREATE INDEX IF NOT EXISTS idx_parks_lat_lng ON public.parks (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_checkins_park_active ON public.park_checkins (park_id, is_active);
CREATE INDEX IF NOT EXISTS idx_checkins_user_active ON public.park_checkins (user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_checkins_checked_in_at ON public.park_checkins (checked_in_at DESC);

-- RLS
ALTER TABLE public.parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.park_checkins ENABLE ROW LEVEL SECURITY;

-- Parks: readable by all
DROP POLICY IF EXISTS parks_select_all ON public.parks;
CREATE POLICY parks_select_all ON public.parks
  FOR SELECT USING (true);

-- Parks: insert/update/delete restricted to admins (simplify: no one via RLS, seed via admin)
DROP POLICY IF EXISTS parks_no_modify ON public.parks;
CREATE POLICY parks_no_modify ON public.parks
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- Park checkins: users can manage own rows
DROP POLICY IF EXISTS checkins_select_public ON public.park_checkins;
CREATE POLICY checkins_select_public ON public.park_checkins
  FOR SELECT USING (
    -- Anyone can read active check-ins; historical visible to owner only
    is_active OR auth.uid() = user_id
  );

DROP POLICY IF EXISTS checkins_insert_own ON public.park_checkins;
CREATE POLICY checkins_insert_own ON public.park_checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS checkins_update_own ON public.park_checkins;
CREATE POLICY checkins_update_own ON public.park_checkins
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS checkins_delete_own ON public.park_checkins;
CREATE POLICY checkins_delete_own ON public.park_checkins
  FOR DELETE USING (auth.uid() = user_id);

-- Seed minimal parks (idempotent by name)
INSERT INTO public.parks (name, address, latitude, longitude)
SELECT * FROM (VALUES
  ('Central Park', '123 Park Avenue', 40.7829, -73.9654),
  ('Riverside Dog Park', '456 River Street', 40.8000, -73.9700),
  ('Sunset Beach Park', '789 Beach Road', 34.0195, -118.4912)
) AS v(name, address, latitude, longitude)
WHERE NOT EXISTS (
  SELECT 1 FROM public.parks p WHERE p.name = v.name
);
