import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barkdate/features/map/domain/repositories/map_repository.dart';
import 'package:barkdate/features/map/data/repositories/map_repository_impl.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/models/event.dart';

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepositoryImpl();
});

// Viewport state
class MapViewport {
  final LatLng center;
  final double zoom;
  final LatLngBounds? bounds;

  MapViewport({
    this.center = const LatLng(40.7128, -74.0060), // NYC default
    this.zoom = 14.0,
    this.bounds,
  });

  MapViewport copyWith({
    LatLng? center,
    double? zoom,
    LatLngBounds? bounds,
  }) {
    return MapViewport(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      bounds: bounds ?? this.bounds,
    );
  }
}

final mapViewportProvider = StateProvider<MapViewport>((ref) => MapViewport());

// Filter state
class MapFilters {
  final String searchQuery;
  final bool showEvents;
  final bool openNow;
  final String category; // 'all', 'park', 'cafe', 'store'
  final List<String> amenities;
  final List<String>? aiSuggestedPlaceNames; // New field for AI grounding

  MapFilters({
    this.searchQuery = '',
    this.showEvents = true,
    this.openNow = false,
    this.category = 'all',
    this.amenities = const [],
    this.aiSuggestedPlaceNames,
  });

  MapFilters copyWith({
    String? searchQuery,
    bool? showEvents,
    bool? openNow,
    String? category,
    List<String>? amenities,
    List<String>? aiSuggestedPlaceNames,
  }) {
    return MapFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      showEvents: showEvents ?? this.showEvents,
      openNow: openNow ?? this.openNow,
      category: category ?? this.category,
      amenities: amenities ?? this.amenities,
      aiSuggestedPlaceNames: aiSuggestedPlaceNames ?? this.aiSuggestedPlaceNames,
    );
  }
}

final mapFiltersProvider = StateNotifierProvider<MapFiltersNotifier, MapFilters>((ref) => MapFiltersNotifier());

// Data state
class MapData {
  final List<PlaceResult> places;
  final List<Event> events;
  final Map<String, int> checkInCounts;

  MapData({
    this.places = const [],
    this.events = const [],
    this.checkInCounts = const {},
  });
}

final mapDataProvider = FutureProvider<MapData>((ref) async {
  final repository = ref.watch(mapRepositoryProvider);
  final viewport = ref.watch(mapViewportProvider);
  final filters = ref.watch(mapFiltersProvider);

  // Don't fetch if bounds are null (map not ready)
  if (viewport.bounds == null) {
    return MapData();
  }

  List<PlaceResult> places = [];

  // Logic: If AI suggestions exist, search for EACH of them.
  // Otherwise, do normal search.
  if (filters.aiSuggestedPlaceNames != null && filters.aiSuggestedPlaceNames!.isNotEmpty) {
    // Parallel search for all AI suggestions
    final futures = filters.aiSuggestedPlaceNames!.map((name) => repository.searchPlaces(
      latitude: viewport.center.latitude,
      longitude: viewport.center.longitude,
      radius: 10000, // Wider radius for specific AI suggestions
      keyword: name,
    ));
    
    final results = await Future.wait(futures);
    // Flatten and deduplicate
    final uniquePlaces = <String, PlaceResult>{};
    for (var list in results) {
      for (var place in list) {
        uniquePlaces[place.placeId] = place;
      }
    }
    places = uniquePlaces.values.toList();
    
  } else {
    // Normal Search
    places = await repository.searchPlaces(
      latitude: viewport.center.latitude,
      longitude: viewport.center.longitude,
      radius: 5000, // 5km search radius
      keyword: filters.searchQuery.isEmpty ? null : filters.searchQuery,
    );
  }

  // Fetch events if enabled
  List<Event> events = [];
  if (filters.showEvents) {
    events = await repository.getEventsInViewport(
      south: viewport.bounds!.southwest.latitude,
      west: viewport.bounds!.southwest.longitude,
      north: viewport.bounds!.northeast.latitude,
      east: viewport.bounds!.northeast.longitude,
    );
  }

  // Fetch check-in counts
  final placeIds = places.map((p) => p.placeId).toList();
  final checkInCounts = await repository.getCheckInCounts(placeIds);

  return MapData(
    places: places,
    events: events,
    checkInCounts: checkInCounts,
  );
});

// Selection state
class MapSelection {
  final PlaceResult? selectedPlace;
  final Event? selectedEvent;
  final bool showAiAssistant;

  MapSelection({
    this.selectedPlace,
    this.selectedEvent,
    this.showAiAssistant = false,
  });

  bool get hasSelection => selectedPlace != null || selectedEvent != null || showAiAssistant;

  MapSelection copyWith({
    PlaceResult? selectedPlace,
    Event? selectedEvent,
    bool? showAiAssistant,
  }) {
    return MapSelection(
      selectedPlace: selectedPlace,
      selectedEvent: selectedEvent,
      showAiAssistant: showAiAssistant ?? this.showAiAssistant,
    );
  }
}

class MapSelectionNotifier extends StateNotifier<MapSelection> {
  MapSelectionNotifier() : super(MapSelection());

  void selectPlace(PlaceResult place) {
    state = MapSelection(selectedPlace: place);
  }

  void selectEvent(Event event) {
    state = MapSelection(selectedEvent: event);
  }

  void showAiAssistant() {
    state = MapSelection(showAiAssistant: true);
  }

  void clearSelection() {
    state = MapSelection();
  }
}

final mapSelectionProvider = StateNotifierProvider<MapSelectionNotifier, MapSelection>((ref) {
  return MapSelectionNotifier();
});

class MapFiltersNotifier extends StateNotifier<MapFilters> {
  MapFiltersNotifier() : super(MapFilters());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setShowEvents(bool show) {
    state = state.copyWith(showEvents: show);
  }

  void setOpenNow(bool open) {
    state = state.copyWith(openNow: open);
  }
  
  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void toggleAmenity(String amenity) {
    final current = List<String>.from(state.amenities);
    if (current.contains(amenity)) {
      current.remove(amenity);
    } else {
      current.add(amenity);
    }
    state = state.copyWith(amenities: current);
  }

  void setAiSuggestions(List<String> names) {
    state = state.copyWith(aiSuggestedPlaceNames: names);
  }

  void clearAiSuggestions() {
    state = state.copyWith(aiSuggestedPlaceNames: []);
  }
}
