import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class PlacesService {
  static const String _apiKey = 'AIzaSyCMfjL_HJ22QOnNTDCX2idk25cjg9lv2IY';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Search for dog parks and dog-friendly places
  static Future<List<PlaceResult>> searchDogFriendlyPlaces({
    required double latitude,
    required double longitude,
    int radius = 5000, // 5km default
    String? keyword,
  }) async {
    final List<PlaceResult> allResults = [];

    try {
      // Search for dog parks
      final dogParks = await _searchNearby(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        type: 'park',
        keyword: keyword ?? 'dog park',
      );
      allResults.addAll(dogParks);

      // Search for pet stores if no specific keyword
      if (keyword == null || keyword.isEmpty) {
        final petStores = await _searchNearby(
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          type: 'pet_store',
          keyword: 'pet store',
        );
        allResults.addAll(petStores);

        // Search for veterinary services
        final vets = await _searchNearby(
          latitude: latitude,
          longitude: longitude,
          radius: radius,
          type: 'veterinary_care',
          keyword: 'veterinary',
        );
        allResults.addAll(vets);
      }

      // Sort by distance and remove duplicates
      final uniqueResults = <String, PlaceResult>{};
      for (final result in allResults) {
        uniqueResults[result.placeId] = result;
      }
      
      final resultList = uniqueResults.values.toList();
      resultList.sort((a, b) => a.distance.compareTo(b.distance));
      
      return resultList.take(20).toList(); // Limit to 20 results
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  static Future<List<PlaceResult>> _searchNearby({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
    required String keyword,
  }) async {
    try {
      final url = '$_baseUrl/nearbysearch/json?'
          'location=$latitude,$longitude&'
          'radius=$radius&'
          'type=$type&'
          'keyword=$keyword&'
          'key=$_apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return results.map((place) {
          final location = place['geometry']['location'];
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            location['lat'],
            location['lng'],
          );
          
          return PlaceResult(
            placeId: place['place_id'],
            name: place['name'],
            address: place['vicinity'] ?? '',
            latitude: location['lat'],
            longitude: location['lng'],
            rating: (place['rating'] ?? 0.0).toDouble(),
            userRatingsTotal: place['user_ratings_total'] ?? 0,
            isOpen: _getOpenStatus(place),
            category: _getCategory(type),
            distance: distance,
            photoReference: _getPhotoReference(place),
          );
        }).toList();
      } else {
        debugPrint('Places API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Network error searching places: $e');
      return [];
    }
  }

  // Get place details
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = '$_baseUrl/details/json?'
          'place_id=$placeId&'
          'fields=name,formatted_address,formatted_phone_number,website,opening_hours,reviews,photos&'
          'key=$_apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      } else {
        debugPrint('Place details API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
    }
  }

  // Autocomplete for admin interface
  static Future<List<PlaceAutocomplete>> autocomplete(String input) async {
    if (input.isEmpty) return [];
    
    try {
      final url = '$_baseUrl/autocomplete/json?'
          'input=$input&'
          'types=establishment&'
          'key=$_apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List;
        
        return predictions.map((prediction) => PlaceAutocomplete(
          placeId: prediction['place_id'],
          description: prediction['description'],
          structuredFormatting: PlaceStructuredFormatting(
            mainText: prediction['structured_formatting']['main_text'],
            secondaryText: prediction['structured_formatting']['secondary_text'] ?? '',
          ),
        )).toList();
      } else {
        debugPrint('Autocomplete API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error with autocomplete: $e');
      return [];
    }
  }

  // Get place details by place ID for admin
  static Future<Map<String, dynamic>?> getPlaceDetailsByPlaceId(String placeId) async {
    try {
      final url = '$_baseUrl/details/json?'
          'place_id=$placeId&'
          'fields=name,formatted_address,geometry,rating,user_ratings_total,photos&'
          'key=$_apiKey';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      } else {
        debugPrint('Place details API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      return null;
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

  static String? _getPhotoReference(Map<String, dynamic> place) {
    final photos = place['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      return photos.first['photo_reference'];
    }
    return null;
  }

  // Get photo URL from photo reference
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo?'
        'maxwidth=$maxWidth&'
        'photo_reference=$photoReference&'
        'key=$_apiKey';
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
