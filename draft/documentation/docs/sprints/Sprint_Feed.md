# Sprint: Feed Tab Polish (Geo Discovery + Matching)

## Goals
- Make discovery truly local with distance-based filtering and UX polish.
- Solidify bark/match logic and notifications.

## Scope
- Client
  - Compute distance using current location; filter by radius.
  - Dog detail with clear CTAs; better empty states.
  - Filter persistence and reset.
- Backend
  - Add geo fields to dogs or a `dog_locations` table.
  - PostGIS and indexes for efficient nearby queries (optional but recommended).
  - Ensure matches includes `bark_count`, `last_bark_at`, unique constraints.
- Notifications
  - Push for mutual matches using Edge Functions.

## Deliverables
- Nearby dogs reflect real distance; filter works.
- Mutual bark UX is clear and spam-safe.

## Acceptance Criteria
- Feed returns dogs within N km; distance on card matches expectation.
- Duplicate barks throttled (24h);
- Mutual bark sends both in-app and push notifications.

## Tasks
1) Backend
   - Add/verify geo fields and indexes.
   - Add constraints to matches to avoid duplicates.
2) Client
   - Pull location, compute distance, show on cards.
   - Filter UI uses distance and breeds/size/age.
3) QA & polish
   - Edge cases: no location permission, no dogs found.

## Risks/Notes
- Location permissions and fallbacks.
- Performance for large lists; consider pagination.
