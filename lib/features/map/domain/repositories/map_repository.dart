import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/models/event.dart';

abstract class MapRepository {
  Future<List<PlaceResult>> searchPlaces({
    required double latitude,
    required double longitude,
    required double radius,
    String? keyword,
  });

  Future<List<Event>> getEventsInViewport({
    required double south,
    required double west,
    required double north,
    required double east,
  });

  Future<Map<String, int>> getCheckInCounts(List<String> placeIds);
}
