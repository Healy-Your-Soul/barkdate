import 'package:barkdate/features/map/domain/repositories/map_repository.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/events_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/services/park_service.dart';
import 'package:barkdate/models/event.dart';
import 'package:geolocator/geolocator.dart';

class MapRepositoryImpl implements MapRepository {
  final EventsService _eventsService = EventsService();

  @override
  Future<List<PlaceResult>> searchPlaces({
    required double latitude,
    required double longitude,
    required double radius,
    String? keyword,
  }) async {
    PlaceSearchResult googleResult;
    
    if (keyword != null && keyword.isNotEmpty) {
      // Use Text Search for specific keywords (e.g. from AI or user search)
      googleResult = await PlacesService.searchPlacesByText(
        textQuery: keyword,
        latitude: latitude,
        longitude: longitude,
        radius: radius.toInt(),
      );
    } else {
      // Use Nearby Search for generic "search this area"
      googleResult = await PlacesService.searchDogFriendlyPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: radius.toInt(),
        keyword: null, // Don't pass keyword to nearby search as it filters too strictly
      );
    }
    
    // Also fetch featured parks from Supabase (admin-added parks)
    final featuredParks = await ParkService.getFeaturedParks();
    
    // Convert featured parks to PlaceResult for consistent display
    final featuredPlaceResults = featuredParks.map((park) {
      final distance = Geolocator.distanceBetween(
        latitude, longitude, park.latitude, park.longitude,
      );
      
      return PlaceResult(
        placeId: 'featured_${park.id}',
        name: park.name,
        address: park.address ?? '',
        latitude: park.latitude,
        longitude: park.longitude,
        rating: 5.0, // Featured parks get 5 stars
        userRatingsTotal: 0,
        isOpen: true,
        category: PlaceCategory.park,
        distance: distance,
        photoReference: park.photoUrls?.isNotEmpty == true ? park.photoUrls!.first : null,
        isFeaturedPark: true, // Admin-verified dog-friendly location
      );
    }).toList();
    
    // Filter featured parks if keyword search
    List<PlaceResult> filteredFeatured = featuredPlaceResults;
    if (keyword != null && keyword.isNotEmpty) {
      final keywordLower = keyword.toLowerCase();
      filteredFeatured = featuredPlaceResults.where((place) {
        return place.name.toLowerCase().contains(keywordLower) ||
               place.address.toLowerCase().contains(keywordLower);
      }).toList();
    }
    
    // Filter by radius
    filteredFeatured = filteredFeatured.where((place) {
      return place.distance <= radius;
    }).toList();
    
    // Merge and return, featured parks first as they're highlighted
    return [...filteredFeatured, ...googleResult.places];
  }

  @override
  Future<List<Event>> getEventsInViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    return await _eventsService.fetchEventsInViewport(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  @override
  Future<Map<String, int>> getCheckInCounts(List<String> placeIds) async {
    return await CheckInService.getPlaceDogCounts(placeIds);
  }
}
