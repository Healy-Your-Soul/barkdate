import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filter state for map places and events
class MapFilters {
  final String searchQuery;
  final String category; // 'all', 'cafe', 'park', 'store', 'veterinary'
  final bool openNow;
  final bool showEvents;
  final List<String> amenities;
  final double maxDistanceKm;

  const MapFilters({
    this.searchQuery = '',
    this.category =
        'park', // Default to Parks as it's the most important feature
    this.openNow = false,
    this.showEvents = true,
    this.amenities = const [],
    this.maxDistanceKm = 10.0,
  });

  MapFilters copyWith({
    String? searchQuery,
    String? category,
    bool? openNow,
    bool? showEvents,
    List<String>? amenities,
    double? maxDistanceKm,
  }) {
    return MapFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      category: category ?? this.category,
      openNow: openNow ?? this.openNow,
      showEvents: showEvents ?? this.showEvents,
      amenities: amenities ?? this.amenities,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    );
  }

  /// Toggle an amenity filter
  MapFilters toggleAmenity(String amenity) {
    final newAmenities = List<String>.from(amenities);
    if (newAmenities.contains(amenity)) {
      newAmenities.remove(amenity);
    } else {
      newAmenities.add(amenity);
    }
    return copyWith(amenities: newAmenities);
  }

  /// Get primary types for Google Places API based on category
  List<String> get primaryTypes {
    switch (category) {
      case 'cafe':
        return ['cafe', 'restaurant'];
      case 'park':
        return ['park', 'dog_park'];
      case 'store':
        return ['pet_store'];
      case 'veterinary':
        return ['veterinary_care'];
      default:
        return [
          'dog_park',
          'park',
          'pet_store',
          'veterinary_care',
          'cafe',
          'restaurant'
        ];
    }
  }
}

/// Controller for map filters
class MapFiltersController extends StateNotifier<MapFilters> {
  MapFiltersController() : super(const MapFilters());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void setOpenNow(bool openNow) {
    state = state.copyWith(openNow: openNow);
  }

  void setShowEvents(bool showEvents) {
    state = state.copyWith(showEvents: showEvents);
  }

  void toggleAmenity(String amenity) {
    state = state.toggleAmenity(amenity);
  }

  void setMaxDistance(double distanceKm) {
    state = state.copyWith(maxDistanceKm: distanceKm);
  }

  void reset() {
    state = const MapFilters();
  }
}

/// Provider for map filters
final mapFiltersProvider =
    StateNotifierProvider<MapFiltersController, MapFilters>((ref) {
  return MapFiltersController();
});

/// Available amenity filters
class MapAmenities {
  static const String waterBowls = 'dog water bowls';
  static const String shadedAreas = 'shaded areas';
  static const String offLeash = 'off-leash area';
  static const String parking = 'parking available';
  static const String patio = 'dog-friendly patio';

  static List<String> get all => [
        waterBowls,
        shadedAreas,
        offLeash,
        parking,
        patio,
      ];
}

/// Available category filters
class MapCategories {
  static const String all = 'all';
  static const String cafe = 'cafe';
  static const String park = 'park';
  static const String store = 'store';
  static const String veterinary = 'veterinary';

  static List<String> get values => [all, cafe, park, store, veterinary];

  static String displayName(String category) {
    switch (category) {
      case all:
        return 'All Places';
      case cafe:
        return 'Cafes';
      case park:
        return 'Parks';
      case store:
        return 'Pet Stores';
      case veterinary:
        return 'Veterinary';
      default:
        return category;
    }
  }

  static String icon(String category) {
    switch (category) {
      case cafe:
        return '☕';
      case park:
        return '🌳';
      case store:
        return '🏪';
      case veterinary:
        return '🏥';
      default:
        return '📍';
    }
  }
}
