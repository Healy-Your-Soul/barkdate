import 'dart:async';

class PlacesService {
  /// Search for dog-friendly places (simplified mock version)
  static Future<List<PlaceResult>> searchDogFriendlyPlaces({
    required double latitude,
    required double longitude,
    required String keyword,
    int radius = 5000,
  }) async {
    // Return mock data for now to avoid API issues
    return [
      PlaceResult(
        placeId: 'mock_1',
        name: 'Central Dog Park',
        address: '123 Park Ave',
        latitude: latitude + 0.01,
        longitude: longitude + 0.01,
        rating: 4.5,
        userRatingsTotal: 120,
        isOpen: true,
        distanceText: '1.2 km',
        distanceKm: 1.2,
        category: PlaceCategory.park,
      ),
      PlaceResult(
        placeId: 'mock_2', 
        name: 'Riverside Dog Run',
        address: '456 River St',
        latitude: latitude - 0.01,
        longitude: longitude - 0.01,
        rating: 4.2,
        userRatingsTotal: 85,
        isOpen: true,
        distanceText: '0.8 km',
        distanceKm: 0.8,
        category: PlaceCategory.park,
      ),
    ];
  }

  /// Get place details (simplified)
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    // Return mock data
    return PlaceDetails(
      name: 'Mock Park',
      rating: 4.5,
      weekdayText: ['Monday: 6:00 AM – 10:00 PM'],
      reviews: [],
      photoReferences: [],
    );
  }

  /// Get place photos (simplified)
  static Future<List<String>> getPlacePhotos(String placeId) async {
    return [];
  }

  /// Get photo URL from photo reference
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return 'https://via.placeholder.com/$maxWidth';
  }
}

// Simplified data classes
class PlaceResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingsTotal;
  final bool isOpen;
  final String distanceText;
  final double distanceKm;
  final PlaceCategory category;
  final String? photoReference;

  PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingsTotal,
    required this.isOpen,
    required this.distanceText,
    required this.distanceKm,
    required this.category,
    this.photoReference,
  });

  String get photoUrl {
    if (photoReference != null) {
      return PlacesService.getPhotoUrl(photoReference!);
    }
    return '';
  }
}

class PlaceDetails {
  final String name;
  final double rating;
  final String? phoneNumber;
  final String? website;
  final List<String> weekdayText;
  final List<PlaceReview> reviews;
  final List<String> photoReferences;

  PlaceDetails({
    required this.name,
    required this.rating,
    this.phoneNumber,
    this.website,
    required this.weekdayText,
    required this.reviews,
    required this.photoReferences,
  });
}

class PlaceReview {
  final String authorName;
  final double rating;
  final String text;
  final String relativeTimeDescription;

  PlaceReview({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.relativeTimeDescription,
  });
}

enum PlaceCategory {
  park,
  petStore,
  veterinary,
  restaurant,
  other,
}

extension PlaceCategoryExtension on PlaceCategory {
  String get displayName {
    switch (this) {
      case PlaceCategory.park:
        return 'Dog Park';
      case PlaceCategory.petStore:
        return 'Pet Store';
      case PlaceCategory.veterinary:
        return 'Veterinary';
      case PlaceCategory.restaurant:
        return 'Pet-Friendly Restaurant';
      case PlaceCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PlaceCategory.park:
        return '🌳';
      case PlaceCategory.petStore:
        return '🛍️';
      case PlaceCategory.veterinary:
        return '🏥';
      case PlaceCategory.restaurant:
        return '🍽️';
      case PlaceCategory.other:
        return '📍';
    }
  }
}
