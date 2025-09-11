import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class PlacesService {
  static const String _apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
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

      // Sort by distance
      allResults.sort((a, b) => a.distanceText.compareTo(b.distanceText));
      
      return allResults.take(20).toList(); // Limit to 20 results
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
            distanceText: _formatDistance(distance),
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

  static String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
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
      longitude: longitude,
      radius: radius,
      type: 'pet_store',
      keyword: keyword,
    );
    allResults.addAll(petStores);

    // Search for veterinary care
    final vets = await _searchNearby(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      type: 'veterinary_care',
      keyword: keyword,
    );
    allResults.addAll(vets);

    // Search for dog-friendly cafes and restaurants
    if (keyword == null || keyword.toLowerCase().contains('cafe') || keyword.toLowerCase().contains('restaurant')) {
      final cafes = await _searchNearby(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        type: 'restaurant',
        keyword: 'dog friendly',
      );
      allResults.addAll(cafes);
    }

    // Remove duplicates and sort by distance
    final uniqueResults = <String, PlaceResult>{};
    for (final result in allResults) {
      if (!uniqueResults.containsKey(result.placeId)) {
        uniqueResults[result.placeId] = result;
      }
    }

    final resultList = uniqueResults.values.toList();
    resultList.sort((a, b) => a.distance.compareTo(b.distance));
    
    return resultList;
  }

  static Future<List<PlaceResult>> _searchNearby({
    required double latitude,
    required double longitude,
    required int radius,
    required String type,
    String? keyword,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Google Places API key not configured');
    }

    final url = Uri.parse('$_baseUrl/nearbysearch/json').replace(queryParameters: {
      'location': '$latitude,$longitude',
      'radius': radius.toString(),
      'type': type,
      if (keyword != null) 'keyword': keyword,
      'key': _apiKey,
    });

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'] ?? [];
          return results.map((result) => PlaceResult.fromJson(result, latitude, longitude)).toList();
        } else {
          throw Exception('Places API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Places search error: $e');
      return [];
    }
  }

  // Get detailed information about a specific place
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) {
      debugPrint('Google Places API key not configured properly');
      return null;
    }

    final url = Uri.parse('$_baseUrl/details/json').replace(queryParameters: {
      'place_id': placeId,
      'fields': 'name,formatted_address,formatted_phone_number,website,rating,user_ratings_total,opening_hours,photos,reviews,types,geometry',
      'key': _apiKey,
    });

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return data['result'];
        } else {
          debugPrint('Places API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }

  // Get place photos URLs
  static Future<List<String>> getPlacePhotos(String placeId) async {
    try {
      final details = await getPlaceDetails(placeId);
      if (details != null && details['photos'] != null) {
        final photos = details['photos'] as List;
        return photos.map<String>((photo) {
          final photoReference = photo['photo_reference'];
          return '$_baseUrl/photo?maxwidth=400&photo_reference=$photoReference&key=$_apiKey';
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching place photos: $e');
      return [];
    }
  }

  // Text search for places
  static Future<List<PlaceResult>> textSearch({
    required String query,
    required double latitude,
    required double longitude,
    int radius = 10000,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Google Places API key not configured');
    }

    final url = Uri.parse('$_baseUrl/textsearch/json').replace(queryParameters: {
      'query': '$query near $latitude,$longitude',
      'location': '$latitude,$longitude',
      'radius': radius.toString(),
      'key': _apiKey,
    });

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'] ?? [];
          return results.map((result) => PlaceResult.fromJson(result, latitude, longitude)).toList();
        } else {
          throw Exception('Places API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Text search error: $e');
      return [];
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
  final List<String> types;
  final String? photoReference;
  final bool isOpen;
  final double distance; // in meters
  final PlaceCategory category;

  PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.userRatingsTotal,
    required this.types,
    this.photoReference,
    required this.isOpen,
    required this.distance,
    required this.category,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json, double userLat, double userLng) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};
    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;
    
    final distance = Geolocator.distanceBetween(userLat, userLng, lat, lng);
    
    final types = List<String>.from(json['types'] ?? []);
    final category = _categorizePlace(types);
    
    final photos = json['photos'] as List<dynamic>?;
    final photoReference = photos?.isNotEmpty == true 
        ? photos!.first['photo_reference'] as String?
        : null;

    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final isOpen = openingHours?['open_now'] as bool? ?? true;

    return PlaceResult(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      address: json['vicinity'] as String? ?? json['formatted_address'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['user_ratings_total'] as int? ?? 0,
      types: types,
      photoReference: photoReference,
      isOpen: isOpen,
      distance: distance,
      category: category,
    );
  }

  static PlaceCategory _categorizePlace(List<String> types) {
    if (types.contains('park')) return PlaceCategory.park;
    if (types.contains('pet_store')) return PlaceCategory.petStore;
    if (types.contains('veterinary_care')) return PlaceCategory.veterinary;
    if (types.contains('restaurant') || types.contains('cafe') || types.contains('meal_takeaway')) {
      return PlaceCategory.restaurant;
    }
    return PlaceCategory.other;
  }

  String get photoUrl {
    if (photoReference == null) return '';
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=${PlacesService._apiKey}';
  }

  String get distanceText {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
}

class PlaceDetails {
  final String name;
  final String address;
  final String? phoneNumber;
  final String? website;
  final double rating;
  final int userRatingsTotal;
  final List<String> weekdayText;
  final List<PlacePhoto> photos;
  final List<PlaceReview> reviews;
  final List<String> types;

  PlaceDetails({
    required this.name,
    required this.address,
    this.phoneNumber,
    this.website,
    required this.rating,
    required this.userRatingsTotal,
    required this.weekdayText,
    required this.photos,
    required this.reviews,
    required this.types,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;
    final weekdayText = openingHours != null 
        ? List<String>.from(openingHours['weekday_text'] ?? [])
        : <String>[];

    final photosJson = json['photos'] as List<dynamic>? ?? [];
    final photos = photosJson.map((p) => PlacePhoto.fromJson(p)).toList();

    final reviewsJson = json['reviews'] as List<dynamic>? ?? [];
    final reviews = reviewsJson.map((r) => PlaceReview.fromJson(r)).toList();

    return PlaceDetails(
      name: json['name'] as String? ?? '',
      address: json['formatted_address'] as String? ?? '',
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      userRatingsTotal: json['user_ratings_total'] as int? ?? 0,
      weekdayText: weekdayText,
      photos: photos,
      reviews: reviews,
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class PlacePhoto {
  final String photoReference;
  final int width;
  final int height;

  PlacePhoto({
    required this.photoReference,
    required this.width,
    required this.height,
  });

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    return PlacePhoto(
      photoReference: json['photo_reference'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  String getUrl({int maxWidth = 400}) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=${PlacesService._apiKey}';
  }
}

class PlaceReview {
  final String authorName;
  final String authorUrl;
  final String text;
  final double rating;
  final String relativeTimeDescription;

  PlaceReview({
    required this.authorName,
    required this.authorUrl,
    required this.text,
    required this.rating,
    required this.relativeTimeDescription,
  });

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    return PlaceReview(
      authorName: json['author_name'] as String? ?? '',
      authorUrl: json['author_url'] as String? ?? '',
      text: json['text'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      relativeTimeDescription: json['relative_time_description'] as String? ?? '',
    );
  }
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
        return 'Dog-Friendly Restaurant';
      case PlaceCategory.other:
        return 'Pet-Friendly Place';
    }
  }

  String get icon {
    switch (this) {
      case PlaceCategory.park:
        return '🏞️';
      case PlaceCategory.petStore:
        return '🏪';
      case PlaceCategory.veterinary:
        return '🏥';
      case PlaceCategory.restaurant:
        return '🍽️';
      case PlaceCategory.other:
        return '📍';
    }
  }
}
