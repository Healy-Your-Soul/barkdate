import 'dart:convert';
import 'dart:js' as js;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class PlacesService {
  // Search for dog parks and dog-friendly places using the JS Maps API
  static Future<List<PlaceResult>> searchDogFriendlyPlaces({
    required double latitude,
    required double longitude,
    int radius = 5000, // 5km default
    String? keyword,
  }) async {
    // For now, return a combination of featured parks and mock Google Places data
    // This avoids CORS issues while still providing search functionality
    return _getMockPlacesForLocation(latitude, longitude, keyword);
  }

  static List<PlaceResult> _getMockPlacesForLocation(
    double latitude, 
    double longitude, 
    String? keyword
  ) {
    // Mock places around the searched location
    final mockPlaces = [
      PlaceResult(
        placeId: 'mock_emerald_park',
        name: 'Emerald Park',
        address: 'Emerald Park, Perth WA',
        latitude: latitude + 0.001,
        longitude: longitude + 0.001,
        rating: 4.5,
        userRatingsTotal: 324,
        isOpen: true,
        category: PlaceCategory.park,
        distance: Geolocator.distanceBetween(latitude, longitude, latitude + 0.001, longitude + 0.001),
        photoReference: null,
      ),
      PlaceResult(
        placeId: 'mock_dog_park_1',
        name: 'Riverside Dog Park',
        address: 'Near ${keyword ?? "your location"}',
        latitude: latitude + 0.002,
        longitude: longitude - 0.001,
        rating: 4.2,
        userRatingsTotal: 156,
        isOpen: true,
        category: PlaceCategory.park,
        distance: Geolocator.distanceBetween(latitude, longitude, latitude + 0.002, longitude - 0.001),
        photoReference: null,
      ),
      PlaceResult(
        placeId: 'mock_pet_store_1',
        name: 'Petbarn',
        address: 'Local Pet Store',
        latitude: latitude - 0.001,
        longitude: longitude + 0.002,
        rating: 4.8,
        userRatingsTotal: 89,
        isOpen: true,
        category: PlaceCategory.petStore,
        distance: Geolocator.distanceBetween(latitude, longitude, latitude - 0.001, longitude + 0.002),
        photoReference: null,
      ),
      PlaceResult(
        placeId: 'mock_vet_1',
        name: 'Perth Veterinary Hospital',
        address: 'Veterinary Services',
        latitude: latitude + 0.003,
        longitude: longitude + 0.001,
        rating: 4.6,
        userRatingsTotal: 234,
        isOpen: true,
        category: PlaceCategory.veterinary,
        distance: Geolocator.distanceBetween(latitude, longitude, latitude + 0.003, longitude + 0.001),
        photoReference: null,
      ),
    ];

    // Filter by keyword if provided
    if (keyword != null && keyword.isNotEmpty) {
      return mockPlaces.where((place) => 
        place.name.toLowerCase().contains(keyword.toLowerCase()) ||
        place.address.toLowerCase().contains(keyword.toLowerCase())
      ).toList();
    }

    return mockPlaces;
  }

  // Get place details - mock for now
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    // Return mock details
    return {
      'name': 'Mock Place Details',
      'formatted_address': '123 Demo Street, Demo City',
      'formatted_phone_number': '+61 8 1234 5678',
      'website': 'https://example.com',
      'opening_hours': {
        'weekday_text': [
          'Monday: 6:00 AM – 10:00 PM',
          'Tuesday: 6:00 AM – 10:00 PM',
          'Wednesday: 6:00 AM – 10:00 PM',
          'Thursday: 6:00 AM – 10:00 PM',
          'Friday: 6:00 AM – 10:00 PM',
          'Saturday: 7:00 AM – 9:00 PM',
          'Sunday: 7:00 AM – 9:00 PM',
        ]
      },
      'reviews': []
    };
  }

  // Simple autocomplete for admin - mock for now to avoid CORS
  static Future<List<PlaceAutocomplete>> autocomplete(String input) async {
    if (input.isEmpty) return [];
    
    // Return mock autocomplete results based on input
    return [
      PlaceAutocomplete(
        placeId: 'mock_auto_emerald',
        description: 'Emerald Park - Perth WA, Australia',
        structuredFormatting: PlaceStructuredFormatting(
          mainText: 'Emerald Park',
          secondaryText: 'Perth WA, Australia',
        ),
      ),
      PlaceAutocomplete(
        placeId: 'mock_auto_riverside',
        description: 'Riverside Dog Park - Perth WA, Australia',
        structuredFormatting: PlaceStructuredFormatting(
          mainText: 'Riverside Dog Park',
          secondaryText: 'Perth WA, Australia',
        ),
      ),
      PlaceAutocomplete(
        placeId: 'mock_auto_kings',
        description: 'Kings Park - Perth WA, Australia',
        structuredFormatting: PlaceStructuredFormatting(
          mainText: 'Kings Park',
          secondaryText: 'Perth WA, Australia',
        ),
      ),
    ].where((place) => 
      place.structuredFormatting.mainText.toLowerCase().contains(input.toLowerCase()) ||
      place.description.toLowerCase().contains(input.toLowerCase())
    ).toList();
  }

  // Get place details by place ID for admin
  static Future<Map<String, dynamic>?> getPlaceDetailsByPlaceId(String placeId) async {
    // Mock place details based on place ID
    switch (placeId) {
      case 'mock_auto_emerald':
        return {
          'name': 'Emerald Park',
          'formatted_address': 'Emerald Park, Perth WA 6009, Australia',
          'geometry': {
            'location': {
              'lat': -31.766536,
              'lng': 115.778203,
            }
          },
          'rating': 4.5,
          'user_ratings_total': 324,
        };
      case 'mock_auto_riverside':
        return {
          'name': 'Riverside Dog Park',
          'formatted_address': 'Riverside Drive, Perth WA 6000, Australia',
          'geometry': {
            'location': {
              'lat': -31.768536,
              'lng': 115.776203,
            }
          },
          'rating': 4.2,
          'user_ratings_total': 156,
        };
      case 'mock_auto_kings':
        return {
          'name': 'Kings Park',
          'formatted_address': 'Fraser Avenue, Perth WA 6005, Australia',
          'geometry': {
            'location': {
              'lat': -31.764536,
              'lng': 115.780203,
            }
          },
          'rating': 4.8,
          'user_ratings_total': 2341,
        };
      default:
        return {
          'name': 'Unknown Place',
          'formatted_address': 'Perth WA, Australia',
          'geometry': {
            'location': {
              'lat': -31.766536,
              'lng': 115.778203,
            }
          },
          'rating': 4.0,
          'user_ratings_total': 100,
        };
    }
  }

  static bool _getOpenStatus(Map<String, dynamic> place) {
    final openingHours = place['opening_hours'];
    if (openingHours != null) {
      return openingHours['open_now'] ?? false;
    }
    return true; // Assume open if no data
  }

  static PlaceCategory _getCategory(String type) {
    switch (type) {
      case 'park':
        return PlaceCategory.park;
      case 'pet_store':
        return PlaceCategory.petStore;
      case 'veterinary_care':
        return PlaceCategory.veterinary;
      case 'restaurant':
        return PlaceCategory.restaurant;
      default:
        return PlaceCategory.other;
    }
  }

  // Get photo URL from photo reference
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    // Return a placeholder image for now
    return 'https://via.placeholder.com/${maxWidth}x${(maxWidth * 0.6).round()}?text=Dog+Park';
  }
}

// Data classes
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
        return 'Dog-Friendly Cafe';
      case PlaceCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PlaceCategory.park:
        return '🐕';
      case PlaceCategory.petStore:
        return '🏪';
      case PlaceCategory.veterinary:
        return '🏥';
      case PlaceCategory.restaurant:
        return '☕';
      case PlaceCategory.other:
        return '📍';
    }
  }
}

class PlaceResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int userRatingsTotal;
  final bool isOpen;
  final PlaceCategory category;
  final double distance;
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
    required this.category,
    required this.distance,
    this.photoReference,
  });

  String get distanceText {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
}

class PlaceAutocomplete {
  final String placeId;
  final String description;
  final PlaceStructuredFormatting structuredFormatting;

  PlaceAutocomplete({
    required this.placeId,
    required this.description,
    required this.structuredFormatting,
  });
}

class PlaceStructuredFormatting {
  final String mainText;
  final String secondaryText;

  PlaceStructuredFormatting({
    required this.mainText,
    required this.secondaryText,
  });
}
