# Map Tab Rebuild Blueprint (2025-10-28)

A clean-slate plan to rebuild the Map tab from the ground up: robust, fast, and extensible. This guide covers architecture, data flow, UI structure, performance, error handling, testing, and an AI layer using Gemini. It also specifies how to integrate “Dog Events at Nearby Places.” One doc, end-to-end.

---

## Goals

- Smooth, responsive map with clustering, viewport querying, and zero jank.
- Clear separation of layers (data/services/state/UI) with testable contracts.
- First-class search and filtering for dog-friendly places.
- Event Integration: show dog events happening at or near places, with filters and time ranges.
- AI Map Assistant (Gemini) for natural-language search, summaries, and suggestions.
- Offline-aware caching and graceful error handling.

### Non-Goals
- Rewriting non-map parts of the app.
- Replacing existing backend unless noted.

---

## Final UX Snapshot (What we’re building)

- Tab shows a Google Map centered on the user, with clustered markers for places.
- Search bar supports text and AI queries; filter chips for categories, rating, distance, open-now, event-only.
- Tapping a marker opens a bottom sheet with place details and upcoming events.
- A toggle to “Show Events” adds event badges to place markers and an Events Sheet listing items within the viewport/time window.
- Optional AI panel: users type a natural sentence (e.g., “dog-friendly cafes with water bowls and events this weekend within 3km”). The assistant returns refined filters + suggested spots.

---

## Architecture Overview

- UI (Flutter Widgets)
  - MapTabScreen
  - MapView (GoogleMap)
  - SearchBar + FilterChips
  - PlaceMarkerLayer + ClusterLayer
  - BottomSheets: PlaceDetailsSheet, EventsSheet
  - AI Panel: GeminiAssistantSheet
- State (Riverpod or Bloc — pick one; this doc assumes Riverpod)
  - MapViewportController: camera position, bounds, zoom
  - PlaceResultsController: current filters, fetch state, pages/cache
  - EventResultsController: same as above, event-specific
  - SelectionController: selected place/event state
  - AIMediator: orchestrates Gemini calls and merges outputs into filters or suggestions
- Data/Services
  - LocationService (permission + current location)
  - PlacesService (Supabase + Google Places where needed)
  - EventsService (Supabase/DataConnect)
  - GeminiService (google_generative_ai)
  - CacheLayer (in-memory + on-disk)
- Platform/Integrations
  - Google Maps SDK via `google_maps_flutter`
  - Supabase (REST or DataConnect GraphQL)
  - Gemini (google_generative_ai)

### Contracts (tiny API sketch)
- PlacesService
  - fetchPlaces(bbox, filters, pageToken?) -> List<Place>, nextPageToken?
  - placeDetails(placeId) -> PlaceDetails
- EventsService
  - fetchEvents(bbox, timeRange, filters) -> List<Event>
- AIMediator
  - interpretQuery(nlText, context) -> AIMLResult {filters, rankingHints, warnings}

---

## Data Model (App-level)

```text
Place {
  id: String
  name: String
  lat: double
  lng: double
  categories: List<String>
  rating: double?
  openNow: bool?
  placeProvider: "internal" | "google"
}

Event {
  id: String
  placeId: String?  // linked when event is hosted at a known place
  lat: double       // use when not tied to a place
  lng: double
  title: String
  description: String
  startTime: DateTime
  endTime: DateTime
  tags: List<String> // e.g., "meetup", "training", "adoption"
}
```

### Supabase Tables (proposed)

- places(id, name, lat, lng, categories[], rating, open_now, provider, created_at)
- events(id, place_id, lat, lng, title, description, start_time, end_time, tags[], created_at)

Indexes for performance:

```sql
-- Spatial and time indexes
create index if not exists idx_places_lat_lng on places (lat, lng);
create index if not exists idx_events_lat_lng on events (lat, lng);
create index if not exists idx_events_time on events (start_time, end_time);
```

If PostGIS is available, prefer geography columns and use ST_Intersects for bbox queries.

---

## APIs and Queries

### Bounding Box Query (REST via Supabase Dart)

```dart
final resp = await supabase.from('places')
  .select()
  .gte('lat', bbox.south)
  .lte('lat', bbox.north)
  .gte('lng', bbox.west)
  .lte('lng', bbox.east)
  .limit(500) // defensive cap per fetch
  .execute();
```

### DataConnect GraphQL (if using dataconnect/)

- Query places by bbox and filters in `dataconnect/queries.gql`:

```graphql
query PlacesInView($south: Float!, $west: Float!, $north: Float!, $east: Float!, $cats: [String!], $openNow: Boolean) {
  placesInBbox(south: $south, west: $west, north: $north, east: $east, categories: $cats, openNow: $openNow) {
    id
    name
    lat
    lng
    categories
    rating
    open_now
  }
}
```

### Events Near Viewport (time-windowed)

```graphql
query EventsInView($south: Float!, $west: Float!, $north: Float!, $east: Float!, $from: timestamptz!, $to: timestamptz!) {
  eventsInBbox(south: $south, west: $west, north: $north, east: $east, from: $from, to: $to) {
    id
    title
    start_time
    end_time
    place_id
    lat
    lng
    tags
  }
}
```

Fallback: do the same with REST filters if GraphQL isn’t wired.

---

## Permissions & Privacy

- Request location with rationale and a fallback (manual city selection) if denied.
- Do not store precise location without consent; use coarse rounding where analytics are needed.
- Gate AI/Gemini usage behind a setting and disclose prompts may send map context (never send PII).

---

## State Management (Riverpod example)

- MapViewportController: exposes AsyncValue<ViewState> with camera/bounds/zoom.
- PlaceResultsController: watches viewport + filters, debounces, fetches, caches by tile key.
- EventResultsController: same as above but time-windowed (now..+14 days by default).
- SelectionController: selected marker -> detail fetch -> bottom sheet state.
- AIMediator: given NL text + viewport context -> outputs normalized filters and a suggested list.

Minimal provider contracts:

```dart
final mapViewportProvider = StateNotifierProvider<MapViewportController, ViewportState>((ref) => ...);
final placeResultsProvider = FutureProvider.autoDispose<PlacePage>((ref) async { ... });
final eventResultsProvider = FutureProvider.autoDispose<EventPage>((ref) async { ... });
final selectionProvider = StateProvider<Selection?>((ref) => null);
final aiMediatorProvider = Provider<AIMediator>((ref) => GeminiMediator(...));
```

---

## UI Structure & Component Tree

- MapTabScreen
  - AppBar: SearchBar (text + mic + AI icon)
  - Body: Stack
    - GoogleMap
    - Positioned: Recenter FAB, Layers/Filters FAB
    - Positioned: Event toggle chip (on/off)
  - BottomSheet (modal):
    - PlaceDetailsSheet
    - EventsSheet (list of upcoming events in view)
    - GeminiAssistantSheet (AI queries, suggestions)

### Clustering
- Use a cluster manager (e.g., `google_maps_cluster_manager` or custom tile bucketing) to keep markers < 1,000 visible.
- Render cluster markers with count badges; tap to zoom in.

### Bottom Sheets
- PlaceDetailsSheet shows name, rating, open hours, photos, actions, and “Upcoming Events at this place.”
- EventsSheet shows events in viewport (time window, infinite scroll, calendar filters).

---

## Performance & Caching

- Debounce fetches on camera moveEnd (e.g., 250–350ms).
- Cap results per call (e.g., 500 places, 200 events) and paginate with nextPageToken or cursor.
- Cache by tile key (zoom-normalized bbox). TTL ~ 5–10 minutes.
- Use lightweight marker icons (raster sprites) + reuse Bitmaps.
- Avoid setState storms: update markers in batches.
- Pre-fetch details for selected marker + neighbors.

---

## Error Handling

- Location denied -> fallback to manual city selection.
- Network errors -> retry with backoff; show toasts + cached data when available.
- Gemini failures -> show structured warning and fall back to local filters.
- Log errors with context (viewport, filter set, counts) for triage.

---

## Testing Plan

- Unit: services (PlacesService, EventsService, GeminiService) with fake clients.
- Widget: MapTabScreen with fake map and stubbed providers; selection and sheet flows.
- Integration: viewport fetch + cluster + selection; AI query -> filter transform.
- Performance: scroll/zoom benchmarks; worst-case 2,000 markers compressed to clusters within 16ms per frame budget.

---

## Analytics & Observability

- Track: map_open, viewport_fetch, markers_rendered_count, cluster_tap, place_select, event_toggle_on, ai_query_submit, ai_query_apply_filters.
- Include anonymized viewport size (rounded coords) and filter fingerprint.

---

## Security & Secrets

- API keys via env/secret manager. This repo uses `run_with_secrets.sh`; add:
  - GOOGLE_MAPS_API_KEY
  - GOOGLE_PLACES_API_KEY (if separate)
  - GEMINI_API_KEY
  - SUPABASE_URL, SUPABASE_ANON_KEY
- Do not hardcode keys. For web, restrict referrers; for iOS/Android, use app restrictions.

---

## Event Integration: Nearby Dog Events (Feature Spec)

- Toggle chip “Show Events” overlays event badges onto place markers; places with >=1 event show a small calendar dot.
- EventsSheet lists items within viewport for a chosen time window (default: now..+14 days). Filter by tags.
- If an event has `place_id`, it is grouped under that place; else it appears as its own marker.
- Tapping an event opens Event Detail (inline within PlaceDetailsSheet when linked, standalone otherwise).

### Queries
- Events by bbox + time window (GraphQL or REST) capped and paged.
- Preload next page while scrolling EventsSheet.

### Schema notes
- For recurring events, store base event with RRULE string or expand into instances server-side.

---

## Gemini AI Map Integration

Use `google_generative_ai` to interpret NL queries and produce structured filters + suggestions.

### Package
- Add `google_generative_ai` to `pubspec.yaml` and initialize with `GEMINI_API_KEY`.

### Prompting Strategy
- System: “You are an assistant for a dog-places map. Output JSON with filters and rationale.”
- User: includes current viewport, time window (for events), existing filters, and NL text.

### Expected JSON (function-call style)

```json
{
  "filters": {
    "categories": ["cafe", "park"],
    "openNow": true,
    "radiusMeters": 3000,
    "minRating": 4.2,
    "event": {"enabled": true, "from": "2025-10-28T00:00:00Z", "to": "2025-10-30T00:00:00Z", "tags": ["meetup"]}
  },
  "suggestions": [
    {"placeId": "...", "score": 0.9, "reason": "large patio, water bowls"}
  ],
  "warnings": []
}
```

### Flow
1. User taps AI icon, enters NL query.
2. AIMediator sends prompt with context; validates and clamps outputs.
3. Apply filters to map providers; show suggestions as highlighted markers.
4. Log event with anonymized inputs; cache last N AI queries locally.

### Safety & Limits
- Enforce max radius and result caps regardless of AI output.
- Never send PII. Round coordinates in prompt to ~3 decimals by default.
- Backoff on rate limits; show friendly fallback.

---

## Implementation Steps (from scratch)

### ✅ COMPLETED: Flutter Implementation

The map_v2 has been fully implemented in Flutter! Here's what was built:

1. **Dependencies Added** (pubspec.yaml)
   - `google_maps_flutter: ^2.5.0` - Map widget
   - `google_generative_ai: ^0.4.6` - Gemini AI
   - `flutter_riverpod: ^2.4.9` - State management
   - `geolocator: ^10.1.0` - Location services
   - `supabase_flutter: >=1.10.0` - Backend (already present)

2. **Services Created**
   - ✅ `lib/services/gemini_service.dart` - AI assistant with Google Search grounding
   - ✅ `lib/services/events_service.dart` - Fetch events by viewport + time window
   - ✅ `lib/services/places_service.dart` - Already exists with Google Places API

3. **State Management (Riverpod)**
   - ✅ `lib/screens/map_v2/providers/map_viewport_provider.dart` - Camera, bounds, zoom
   - ✅ `lib/screens/map_v2/providers/map_filters_provider.dart` - Search, category, amenities, events toggle
   - ✅ `lib/screens/map_v2/providers/map_selection_provider.dart` - Selected place/event/AI state

4. **UI Components**
   - ✅ `lib/screens/map_v2/map_tab_screen.dart` - Main map screen with GoogleMap
   - ✅ `lib/screens/map_v2/widgets/map_search_bar.dart` - Search input
   - ✅ `lib/screens/map_v2/widgets/map_filter_chips.dart` - Category and amenity filters
   - ✅ `lib/screens/map_v2/widgets/map_bottom_sheets.dart` - Place, Event, AI Assistant sheets

5. **Features Implemented**
   - Real-time viewport-based place fetching
   - Event markers with time-window filtering
   - AI Assistant with Gemini 2.0 Flash
   - Bottom sheets for Place Details, Event Details, AI queries
   - Filter chips for categories, amenities, open-now, show-events
   - User location and recenter button
   - Marker clustering ready (can be added with `google_maps_cluster_manager`)

### Next Steps to Enable map_v2

1. **Set API Keys** in `run_with_secrets.sh`:
   ```bash
   export GEMINI_API_KEY="your_gemini_api_key_here"
   export GOOGLE_MAPS_API_KEY="your_maps_key_here"
   export SUPABASE_URL="your_supabase_url"
   export SUPABASE_ANON_KEY="your_anon_key"
   ```

2. **Add to main.dart** (wrap with ProviderScope):
   ```dart
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   
   void main() async {
     // ... existing setup
     runApp(const ProviderScope(child: MyApp()));
   }
   ```

3. **Wire into MainNavigation** (replace old map tab):
   ```dart
   import 'package:barkdate/screens/map_v2/map_tab_screen.dart';
   
   // In MainNavigation's _pages list:
   const MapTabScreenV2(), // Replace old MapScreen
   ```

4. **Install packages**:
   ```bash
   flutter pub get
   ```

5. **Run with secrets**:
   ```bash
   ./run_with_secrets.sh
   ```

### Optional: Feature Flag Toggle

To A/B test old vs new map, add a setting:

```dart
// In lib/services/settings_service.dart
bool _useMapV2 = true; // Default to new map

bool get useMapV2 => _useMapV2;
void setUseMapV2(bool value) {
  _useMapV2 = value;
  notifyListeners();
}

// In MainNavigation:
SettingsService().useMapV2 ? const MapTabScreenV2() : const MapScreen(),
```

---

## Acceptance Criteria

- Map loads within 2 seconds on warm start; markers appear within 500ms after camera idle.
- Marker clustering prevents >1000 markers from rendering at once.
- Event toggle overlays badges and populates EventsSheet for the current viewport window.
- Search and filters update results without jank; AI-produced filters are validated and capped.
- Errors show helpful messages and fallbacks; app remains interactive offline with cached data.
- Unit, widget, and basic integration tests green; crash-free sessions >99.5%.

---

## Minimal Code Skeletons (illustrative only)

```dart
// MapTabScreen (sketch)
class MapTabScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewport = ref.watch(mapViewportProvider);
    final places = ref.watch(placeResultsProvider);
    final events = ref.watch(eventResultsProvider);
    return Scaffold(
      appBar: AppBar(title: SearchBarWidget()),
      body: Stack(children: [
        GoogleMap(
          onMapCreated: (c) => ref.read(mapViewportProvider.notifier).attach(c),
          onCameraIdle: () => ref.read(mapViewportProvider.notifier).onIdle(),
          myLocationEnabled: true,
          markers: buildMarkers(places, events),
        ),
        Positioned(right: 16, bottom: 16, child: RecenterFab()),
        Positioned(top: 8, right: 16, child: LayerFilterFab()),
      ]),
      bottomSheet: SelectionBottomSheet(),
    );
  }
}
```

---

## Migration Notes

- Keep old map behind a feature flag while building the new tab.
- Introduce new routes/widgets under `lib/screens/map_v2/` and switch the tab target via a config toggle.
- Reuse/replace existing `lib/services/places_service.dart` as needed to match new contracts.

---

## Appendix: Troubleshooting

- Markers not showing: check permissions, camera position, and marker batching.
- Jank on zoom: verify clustering and marker icon reuse.
- AI responses inconsistent: clamp outputs, seed with deterministic instructions, and cache.
- Empty events: widen time window or verify event ingestion jobs.

---

## Next Steps

- Confirm state management choice (Riverpod vs Bloc) and finalize package list.
- Create `map_v2` folder and scaffold controllers + services.
- Implement viewport fetching + clustering first, then sheets, then AI.
- Add event ingestion/authoring flows or ETL to keep events fresh.
