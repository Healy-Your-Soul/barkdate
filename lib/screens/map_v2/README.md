# Map V2 Architecture

Clean, modular map implementation with AI assistant and event integration.

## 📂 Folder Structure

```
lib/screens/map_v2/
├── map_tab_screen.dart          # Main screen with GoogleMap widget
├── providers/
│   ├── map_viewport_provider.dart    # Camera position, bounds, zoom
│   ├── map_filters_provider.dart     # Search, categories, amenities
│   └── map_selection_provider.dart   # Selected place/event/AI state
└── widgets/
    ├── map_search_bar.dart           # Search input
    ├── map_filter_chips.dart         # Horizontal scrolling filters
    └── map_bottom_sheets.dart        # Place/Event/AI sheets
```

## 🎯 Design Principles

1. **Separation of Concerns**: UI, state, and business logic are cleanly separated
2. **Reactive State**: Riverpod providers auto-rebuild widgets when data changes
3. **Composable Widgets**: Small, focused components that can be tested independently
4. **Performance First**: Debounced fetching, marker batching, lazy bottom sheets

## 🔄 State Flow

```
User Action (search, filter, tap marker)
    ↓
Provider Updates (map_filters_provider, map_selection_provider)
    ↓
map_tab_screen listens with ref.watch()
    ↓
Triggers API calls (PlacesService, EventsService, GeminiService)
    ↓
Updates local state (_places, _events, _markers)
    ↓
Rebuilds only affected widgets
```

## 🧩 Provider Responsibilities

### MapViewportProvider
- Tracks camera position (LatLng center, zoom level)
- Stores visible bounds (LatLngBounds for queries)
- Manages GoogleMapController instance
- Provides helper methods: `moveTo()`, `recenter()`

**When to use**: Moving the camera programmatically or querying the current viewport.

### MapFiltersProvider
- Manages search query text
- Tracks selected category (all, cafe, park, store, veterinary)
- Handles amenity toggles (water bowls, shaded areas, etc.)
- Controls "Open Now" and "Show Events" toggles

**When to use**: Reading or updating any filter state.

### MapSelectionProvider
- Tracks which marker is selected (place, event, or AI assistant)
- Controls bottom sheet visibility
- Provides `clearSelection()` to close sheets

**When to use**: Opening/closing bottom sheets or reading the current selection.

## 🎨 Widget Composition

### MapTabScreen (main controller)
- Owns GoogleMap widget
- Fetches places and events on camera idle
- Manages marker set
- Coordinates between providers and services

### MapSearchBar
- Reads/writes to MapFiltersProvider.searchQuery
- Debounces input to avoid excessive re-renders

### MapFilterChips
- Horizontal scroll of FilterChip widgets
- Reads from MapFiltersProvider
- Updates filters on tap

### MapBottomSheets
- Conditional rendering based on MapSelectionProvider
- Three sub-sheets: PlaceDetailsSheet, EventDetailsSheet, GeminiAssistantSheet
- Uses DraggableScrollableSheet for native feel

## 📡 Service Integration

### PlacesService (lib/services/places_service.dart)
- **Used by**: map_tab_screen (viewport fetch)
- **Returns**: List<PlaceResult> with lat/lng, rating, category, etc.
- **API**: Google Places (searchDogFriendlyPlaces)

### EventsService (lib/services/events_service.dart)
- **Used by**: map_tab_screen (when showEvents is true)
- **Returns**: List<Event> within time window
- **API**: Supabase (fetchEventsInViewport)

### GeminiService (lib/services/gemini_service.dart)
- **Used by**: GeminiAssistantSheet (AI queries)
- **Returns**: GeminiResponse with text + sources
- **API**: Google Generative AI (Gemini 2.0 Flash)

## 🚀 Performance Optimizations

1. **Debounced Fetching**: Camera idle waits 300ms before triggering fetch
2. **Marker Batching**: All markers updated in one setState call
3. **Lazy Sheets**: Bottom sheets only built when selection exists
4. **Provider Auto-Dispose**: Riverpod cleans up unused providers automatically
5. **Viewport Filtering**: Only fetch data within visible bounds + buffer

## 🧪 Testing Strategy

### Unit Tests (providers)
```dart
test('MapFiltersProvider toggles amenity', () {
  final container = ProviderContainer();
  final controller = container.read(mapFiltersProvider.notifier);
  
  controller.toggleAmenity('dog water bowls');
  expect(container.read(mapFiltersProvider).amenities, contains('dog water bowls'));
  
  controller.toggleAmenity('dog water bowls');
  expect(container.read(mapFiltersProvider).amenities, isEmpty);
});
```

### Widget Tests (UI)
```dart
testWidgets('MapSearchBar updates filter on input', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: MapSearchBar()),
    ),
  );
  
  await tester.enterText(find.byType(TextField), 'park');
  await tester.pump();
  
  // Verify filter updated...
});
```

### Integration Tests (E2E)
```dart
testWidgets('Tapping marker opens bottom sheet', (tester) async {
  // 1. Load map
  // 2. Wait for markers
  // 3. Tap marker
  // 4. Verify PlaceDetailsSheet visible
});
```

## 🔐 Security Notes

- **API Keys**: Never hardcode. Use `--dart-define` or secure storage.
- **Location**: Request permissions with clear rationale.
- **Gemini Queries**: Do not send PII (user IDs, names, emails). Only lat/lng and query text.
- **Sources**: Validate Gemini grounding links before display.

## 📈 Monitoring & Analytics

Track these events:
- `map_tab_opened` (tab switch)
- `map_viewport_changed` (camera idle with bbox)
- `map_place_selected` (marker tap with category)
- `map_event_selected` (event marker tap)
- `map_ai_query_submitted` (Gemini query text)
- `map_filter_applied` (which filters active)

Include metadata:
- Viewport size (rounded to avoid fingerprinting)
- Number of markers visible
- Response times (fetch duration)

## 🛠 Future Enhancements

- [ ] Marker clustering (google_maps_cluster_manager)
- [ ] Tile-based caching (viewport hash as key)
- [ ] Custom marker icons (BitmapDescriptor.fromAssetImage)
- [ ] "Search This Area" button
- [ ] Gemini filter parsing (JSON function calling)
- [ ] Dark mode map styling
- [ ] Prefetch place details on marker hover
- [ ] Event calendar sheet (weekly/monthly view)
- [ ] Directions button (launch Google Maps)
- [ ] Save favorite places (local storage)

## 📚 Related Docs

- [MAP_TAB_REBUILD_GUIDE.md](../../MAP_TAB_REBUILD_GUIDE.md) - Architecture blueprint
- [MAP_V2_IMPLEMENTATION_COMPLETE.md](../../MAP_V2_IMPLEMENTATION_COMPLETE.md) - What we built
- [Riverpod Docs](https://riverpod.dev/) - State management
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter) - Map widget
- [Google Generative AI](https://pub.dev/packages/google_generative_ai) - Gemini SDK
