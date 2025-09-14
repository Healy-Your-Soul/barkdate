# Sprint: Map Tab MVP (Live Map, Check-ins, Active Dogs)

## Goals
- Replace placeholder map with Google Maps SDK.
- Implement user check-in/out to parks with real-time presence.
- Display nearby parks and active dogs per park.

## Scope
- Client (Flutter)
  - Integrate `google_maps_flutter` for map rendering and markers.
  - Request and handle location permissions; show user location.
  - Replace current placeholder in `MapScreen` with interactive map + marker clustering.
  - Implement Check-in/Check-out button; show status in UI.
  - Park detail bottom sheet with actions: Directions, Invite to Playdate, View active dogs.
- Backend (Supabase)
  - Tables:
    - parks(id, name, address, lat, lng, metadata, created_at)
    - park_checkins(id, user_id, dog_id, park_id, lat, lng, checked_in_at, checked_out_at, is_active)
  - RLS policies so users can manage their own check-ins; read active check-ins by park.
  - Optional: PostGIS + geo indexes for proximity queries.
- Realtime
  - Subscribe to `park_checkins` changes for visible parks, keep counts fresh.

## Deliverables
- Map UX with markers and clusters.
- Persistent check-in/out backed by Supabase with real-time updates.
- Seed parks (starter list for testing) or Places lookup stub.

## Acceptance Criteria
- User can check in to current park and is visible to others within seconds.
- Active dog counts update without refresh.
- Directions opens external maps app.

## Data Model
- parks
  - id: uuid (pk)
  - name: text
  - address: text
  - latitude: double
  - longitude: double
  - metadata: jsonb (nullable)
  - created_at: timestamptz default now()
- park_checkins
  - id: uuid (pk)
  - park_id: uuid fk parks(id)
  - user_id: uuid fk users(id)
  - dog_id: uuid fk dogs(id)
  - latitude: double
  - longitude: double
  - checked_in_at: timestamptz default now()
  - checked_out_at: timestamptz (nullable)
  - is_active: boolean default true

## API/Policies
- Insert check-in: user can insert with auth.uid() = user_id.
- Update own check-in to set checked_out_at and is_active false.
- Select: anyone can read active check-ins aggregated by park.

## Tasks
1) Dependencies
   - Add google_maps_flutter, geolocator (or location), url_launcher.
   - iOS: add NSLocation usage strings; Android: location permissions and Google Maps key.
2) Supabase schema
   - Create migrations for parks and park_checkins + RLS.
   - Seed 3-5 test parks.
3) Services
   - ParkService: fetch parks nearby, seed if empty.
   - CheckinService: create/end check-in, get active check-ins per park, realtime stream.
4) UI
   - `MapScreen`: render map, markers, cluster, bottom sheets; check-in flow.
5) QA & polish
   - Permission flows, error states, loading skeletons.

## Risks/Notes
- Google Maps API keys management (iOS/Android); use runtime keys or plist/xml.
- Battery/privacy: no continuous tracking; only store events.
- Places/Directions costs—use minimal calls during MVP.
