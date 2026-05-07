# Goal Description

Solve the "Empty Room" problem by allowing admins to seed the map with simulated park activity, and letting verified users report real activity. This creates immediate social proof and "FOMO" by showing users where the dogs are.

We will build a hybrid system: Admins will use an updated `AdminScreen` to quickly seed an area, while regular users will use the standard map interface to report real data (verified by their GPS location).

## Proposed Architecture & Sprints

### Sprint 8a: Database & Core Services
We need to establish the data structure to track these reports over time. By keeping historical data, we can later build a feature that analyzes these reports to show users the "Best time to go" for any given park.

- **Supabase Changes:**
  - Create table `park_activity_reports` (`id`, `park_id`, `reporter_id`, `dog_count`, `is_admin_override`, `created_at`).
  - Add an `is_superadmin` boolean column to the existing `profiles` table so we can securely identify you.
  - Create an RPC function `get_active_parks(viewport)` to fetch non-expired reports.
- **Files Modified:** 
  - `supabase/migrations/xxxx_add_park_activity.sql`
  - `lib/services/park_activity_service.dart` (New)

### Sprint 8b: The Admin Seeding Engine
We will leverage your existing `AdminScreen`. We'll add a new "Seed Area" tool to it.
- **How it works:** You (the admin) open the Admin Screen, pan the map to a target launch area (like a new neighborhood in Perth), and tap "Seed Activity". The app will automatically generate realistic reports (e.g., 3-8 dogs) for a random selection of parks currently visible on your screen.
- **Files Modified:**
  - `lib/screens/admin_screen.dart`
  - `lib/screens/map_v2/map_tab_screen.dart` (To add a secret gesture or button to access the AdminScreen if one doesn't exist).

### Sprint 8c: Map UI & Glowing Animations
When parks have active reports, they need to stand out on the map to create FOMO.
- **How it works:** We will fetch active reports when the map pans. 
  - If a park has `> 5 dogs`, we will render a custom **Glowing Animation** on the map marker (e.g., a pulsing orange ring around the park icon).
  - If `< 5 dogs`, we will show a subtle badge like `🔥 3` attached to the park marker.
- **Files Modified:**
  - `lib/screens/map_v2/map_tab_screen.dart`
  - `lib/screens/map_v2/widgets/glowing_park_marker.dart` (New custom widget overlaid on the map stack, similar to the `WalkMarkerTooltip`).

### Sprint 8d: User Crowdsourcing & Verification
Regular users need a simple, trusted way to report activity.
- **How it works:** When a user taps a park to view its details, we add a "Spotted dogs here? Update count" button.
- **Verification:** To prevent spam, the app will check the user's GPS. If they are not within ~500 meters of the park, the button is disabled with a message "You must be at the park to report". (Admins bypass this restriction).
- **Files Modified:**
  - `lib/screens/map_v2/widgets/simple_place_sheet.dart` (Add the report button/slider).

## User Review Required

> [!IMPORTANT]
> **Admin Identification:** I will create a Supabase migration to add an `is_superadmin` column to the `profiles` table. Once deployed, you will need to manually go into your Supabase dashboard and set this to `TRUE` for your personal user account so you can access the admin tools.

Take a look at the sprints above. Does this phased approach align with your vision? Let me know if you want to proceed and we will kick off **Sprint 8a**!
