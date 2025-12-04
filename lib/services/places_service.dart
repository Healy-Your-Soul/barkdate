import 'dart:async';
import 'dart:js_util';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:barkdate/main.dart';

// Helper function to convert a Dart object to a JS object.
// This is needed because `js.jsify` was removed from the `dart:js` package.
// js.JsObject jsify(Map<String, dynamic> map) {
//   return js.JsObject.jsify(map);
// }

class PlacesService {
  static const List<String> _defaultPrimaryTypes = [
    'dog_park',
    'park',
    'pet_store',
    'veterinary_care',
    'cafe',
    'restaurant',
  ];

  /// Get live autocomplete suggestions from Google Places API using JavaScript interop
  static Future<List<String>> getAutocompleteSuggestions({
    required String input,
    required String apiKey,
    double? latitude,
    double? longitude,
    String? sessionToken,
    String? types,
    String? components,
  }) async {
    if (!kIsWeb) {
      debugPrint('❌ Autocomplete only supported on web platform');
      return [];
    }

    try {
      await mapsApiReadyCompleter.future;

      final Object google =
          _requireJsProperty(globalThis, 'google', 'google namespace not found');
      final Object maps =
          _requireJsProperty(google, 'maps', 'google.maps namespace not found');
      final Object places =
          _requireJsProperty(maps, 'places', 'google.maps.places namespace not found');
      final Object autocompleteStatics = _requireJsProperty(
        places,
        'AutocompleteSuggestion',
        'google.maps.places.AutocompleteSuggestion is unavailable',
      );

      final Map<String, Object?> request = {
        'input': input,
        'language': 'en-AU',
      };

      if (latitude != null && longitude != null) {
        request['locationBias'] = _buildCircleScope(
          latitude: latitude,
          longitude: longitude,
          radius: 50000.0,
        );
      }

      if (types != null && types.isNotEmpty) {
        request['includedPrimaryTypes'] = [types];
      }

      if (components != null && components.isNotEmpty) {
        request['includedRegionCodes'] = [components.toUpperCase()];
      }

      if (sessionToken != null && sessionToken.isNotEmpty) {
        request['sessionToken'] = sessionToken;
      }

      final dynamic response = await promiseToFuture(
        callMethod(autocompleteStatics, 'fetchAutocompleteSuggestions', [jsify(request)]),
      );

      final suggestions = <String>{};

      if (response != null && hasProperty(response, 'suggestions')) {
        final dynamic rawSuggestions = getProperty(response, 'suggestions');
        if (rawSuggestions is List) {
          for (final suggestion in rawSuggestions) {
            final description = _extractSuggestionDescription(suggestion);
            if (description != null && description.isNotEmpty) {
              suggestions.add(description);
            }
          }
        }
      }

      return suggestions.toList(growable: false);
    } catch (e, stackTrace) {
      debugPrint('❌ Google Autocomplete JS error: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }
  
  /// Search for dog-friendly places using the NEW Google Places API (Place.searchNearby)
/// Search for dog-friendly places using the NEW Google Places API (Place.searchNearby)
  static Future<PlaceSearchResult> searchDogFriendlyPlaces({
    required double latitude,
    required double longitude,
    int radius = 5000,
    String? keyword,
    String? pageToken, // Note: pageToken is not directly supported in the new API in the same way
  }) async {
    if (!kIsWeb) {
      debugPrint('❌ Places search only supported on web platform');
      return PlaceSearchResult(places: [], nextPageToken: null);
    }

    try {
      await mapsApiReadyCompleter.future;
      final trimmedKeyword = keyword?.trim();
      final double radiusMeters = radius.clamp(1, 50000).toDouble();

      debugPrint(
        '🔍 NEW Google Places Search: lat=$latitude, lng=$longitude, radius=$radiusMeters, keyword=$keyword',
      );

      // Wait until the Google Maps API is fully loaded and ready.
      await _waitForGoogleMapsApi(verbose: true);

      final completer = Completer<PlaceSearchResult>();

      // Resolve the Places namespace from the global Google Maps object.
      final Object google = _requireJsProperty(globalThis, 'google', 'google namespace not found');
      final Object maps = _requireJsProperty(google, 'maps', 'google.maps namespace not found');
      final Object places =
          _requireJsProperty(maps, 'places', 'google.maps.places namespace not found');
      final Object placeStatics =
          _requireJsProperty(places, 'Place', 'google.maps.places.Place is unavailable');

  // 1. Define the fields you want the API to return.
      final fields = [
        'id',
        'displayName',
        'formattedAddress',
        'location',
        'rating',
        'userRatingCount',
        'primaryType',
        'photos',
        'businessStatus'
        // 'openingHours' is available but requires a separate Place Details request with the new API model.
        // We will assume places are open for now, as before.
      ];
      // 2. Construct the request object for the new API.
      final circleScope = _buildCircleScope(
        latitude: latitude,
        longitude: longitude,
        radius: radiusMeters,
      );

      final Map<String, Object?> baseRequest = {
        'maxResultCount': 20,
        'fields': fields,
        'language': 'en-AU',
        'region': 'AU',
        'includedPrimaryTypes': _defaultPrimaryTypes,
      };
      
      // --- THIS IS THE CORRECTED LOGIC ---
      final bool hasKeyword = trimmedKeyword != null && trimmedKeyword.isNotEmpty;
      String methodName = 'searchNearby'; // Always use searchNearby
      Map<String, Object?> request = {
        ...baseRequest, // This includes 'includedPrimaryTypes'
        'locationRestriction': circleScope,
      };
      // --- END CORRECTION ---

      debugPrint('🧭 Calling Place.$methodName with request: $request');

      String? keywordLower;
      if (hasKeyword) {
        keywordLower = trimmedKeyword!.toLowerCase();
      }

      // 3. Call the selected Place search method, which returns a Promise.
      final promise = callMethod(placeStatics, methodName, [jsify(request)]);

      // 4. Convert the Promise to a Dart Future and process the results.
      promiseToFuture(promise).then((response) {
        debugPrint('📦 Received response from Google Places API');
        debugPrint('📋 Response has "places" property: ${hasProperty(response, 'places')}');
        
        final List<PlaceResult> places = [];
        
        // The response object has a 'places' property which is an array.
        if (hasProperty(response, 'places')) {
          final dynamic rawPlaces = getProperty(response, 'places');
          List resultsList;
          if (rawPlaces is List) {
            resultsList = rawPlaces;
          } else if (rawPlaces is Iterable) {
            resultsList = List.from(rawPlaces);
          } else {
            debugPrint('⚠️ Unexpected places response type: ${rawPlaces.runtimeType}');
            resultsList = const [];
          }
          
          debugPrint('ℹ️ Raw results from Google: ${resultsList.length} places');

          for (var i = 0; i < resultsList.length; i++) {
            try {
              final place = resultsList[i];
              debugPrint('🔍 Processing place ${i + 1}/${resultsList.length}');

              // 5. Safely extract data using camelCase properties from the new API response.
              final name = _extractText(getProperty(place, 'displayName')) ?? 'Unknown';
              debugPrint('  📍 Name: $name');
              
              final location = getProperty(place, 'location');
              if (location == null) {
                debugPrint('  ⚠️ Skipping: no location data');
                continue;
              }

              // Google Places API (new) returns LatLng objects where coordinates
              // are accessed via .lat() and .lng() methods, not properties
              double? lat;
              double? lng;
              
              // Try method calls first (new API LatLng object)
              try {
                final latFn = getProperty(location, 'lat');
                final lngFn = getProperty(location, 'lng');
                if (latFn != null && lngFn != null) {
                  lat = (callMethod(location, 'lat', []) as num?)?.toDouble();
                  lng = (callMethod(location, 'lng', []) as num?)?.toDouble();
                  debugPrint('  📍 Got coords via methods: ($lat, $lng)');
                }
              } catch (e) {
                debugPrint('  ⚠️ Method call failed: $e');
              }
              
              // Fallback to direct property access
              if (lat == null || lng == null) {
                lat = (getProperty(location, 'latitude') as num?)?.toDouble();
                lng = (getProperty(location, 'longitude') as num?)?.toDouble();
                if (lat != null && lng != null) {
                  debugPrint('  📍 Got coords via latitude/longitude: ($lat, $lng)');
                }
              }
              
              // Another fallback - try lat/lng as properties
              if (lat == null || lng == null) {
                lat = (getProperty(location, 'lat') as num?)?.toDouble();
                lng = (getProperty(location, 'lng') as num?)?.toDouble();
                if (lat != null && lng != null) {
                  debugPrint('  📍 Got coords via lat/lng props: ($lat, $lng)');
                }
              }

              if (lat == null || lng == null) {
                debugPrint('  ⚠️ Skipping: could not extract coordinates from location object');
                continue;
              }
              
              debugPrint('  ✅ Coordinates: ($lat, $lng)');

              final vicinity =
                  _extractText(getProperty(place, 'formattedAddress')) ?? '';
              
              // This is our client-side filter
              if (keywordLower != null) {
                final combinedText = '$name $vicinity'.toLowerCase();
                if (!combinedText.contains(keywordLower)) {
                  debugPrint('  ⚠️ Skipping: does not match keyword "$keywordLower"');
                  continue;
                }
              }
              final rating = (getProperty(place, 'rating') as num?)?.toDouble() ?? 0.0;
              final userRatingsTotal = (getProperty(place, 'userRatingCount') as num?)?.toInt() ?? 0;
              final placeId = getProperty(place, 'id') as String? ?? '';
              
              // The new API returns 'businessStatus' which can be 'OPERATIONAL'.
              // We'll consider it "open" if it's operational. A more detailed check
              // would require a follow-up `fetchFields` call for `openingHours`.
              final businessStatus = getProperty(place, 'businessStatus') as String?;
              final isOpen = businessStatus == 'OPERATIONAL';

              // Calculate distance
              final distance = Geolocator.distanceBetween(latitude, longitude, lat, lng);

              // Determine category from primaryType
              PlaceCategory category = PlaceCategory.other;
              final primaryType = getProperty(place, 'primaryType') as String?;
              debugPrint('  🏷️ Primary type: $primaryType');
              
              if (primaryType != null) {
                 if (primaryType.contains('park')) {
                    category = PlaceCategory.park;
                  } else if (primaryType.contains('pet_store')) {
                    category = PlaceCategory.petStore;
                  } else if (primaryType.contains('veterinary_care')) {
                    category = PlaceCategory.veterinary;
                  } else if (primaryType.contains('restaurant') || primaryType.contains('cafe')) {
                    category = PlaceCategory.restaurant;
                  }
              }

              // Get photo reference if available
              String? photoReference;
              if (hasProperty(place, 'photos') && getProperty(place, 'photos') != null) {
                final photos = getProperty(place, 'photos') as List?;
                if (photos != null && photos.isNotEmpty) {
                  final firstPhoto = photos[0];
                  // The photo object itself contains the reference in the new API structure
                  if (hasProperty(firstPhoto, 'name')) {
                     // The 'name' property in the new Photo object holds the resource name needed for getURI
                     photoReference = getProperty(firstPhoto, 'name') as String?;
                  }
                }
              }

              places.add(PlaceResult(
                placeId: placeId,
                name: name,
                address: vicinity,
                latitude: lat,
                longitude: lng,
                rating: rating,
                userRatingsTotal: userRatingsTotal,
                isOpen: isOpen,
                category: category,
                distance: distance,
                photoReference: photoReference,
              ));
              
              debugPrint('  ✅ Added: $name (${category.displayName})');
            } catch (e, stacktrace) {
              debugPrint('⚠️ Error parsing place ${i + 1}: $e');
              debugPrint(stacktrace.toString());
            }
          }
        } else {
          debugPrint('❌ Response does not have "places" property');
        }

        debugPrint('✅ Found ${places.length} places from NEW Google Places API');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        // The new API does not use a token-based pagination model for searchNearby.
        // It returns a single list up to `maxResultCount`.
        completer.complete(PlaceSearchResult(
          places: places,
          nextPageToken: null, // No next page token
        ));

      }).catchError((error) {
        debugPrint('❌ Google Places search promise error: $error');
        completer.complete(PlaceSearchResult(places: [], nextPageToken: null));
      });

      return completer.future;
    } catch (e) {
      debugPrint('❌ Google Places search setup error: $e');
      return PlaceSearchResult(places: [], nextPageToken: null);
    }
  }

  /// Search for places using the NEW Google Places API Text Search (Place.searchByText)
  /// This is better for specific queries like "Central Park" or "Dog friendly cafes"
  static Future<PlaceSearchResult> searchPlacesByText({
    required String textQuery,
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    if (!kIsWeb) {
      debugPrint('❌ Places search only supported on web platform');
      return PlaceSearchResult(places: [], nextPageToken: null);
    }

    try {
      await mapsApiReadyCompleter.future;
      final double radiusMeters = radius.clamp(1, 50000).toDouble();

      debugPrint(
        '🔍 NEW Google Places Text Search: query="$textQuery", lat=$latitude, lng=$longitude, radius=$radiusMeters',
      );

      await _waitForGoogleMapsApi(verbose: true);

      final completer = Completer<PlaceSearchResult>();

      final Object google = _requireJsProperty(globalThis, 'google', 'google namespace not found');
      final Object maps = _requireJsProperty(google, 'maps', 'google.maps namespace not found');
      final Object places = _requireJsProperty(maps, 'places', 'google.maps.places namespace not found');
      final Object placeStatics = _requireJsProperty(places, 'Place', 'google.maps.places.Place is unavailable');

      final fields = [
        'id',
        'displayName',
        'formattedAddress',
        'location',
        'rating',
        'userRatingCount',
        'primaryType',
        'photos',
        'businessStatus'
      ];

      final circleScope = _buildCircleScope(
        latitude: latitude,
        longitude: longitude,
        radius: radiusMeters,
      );

      final Map<String, Object?> request = {
        'textQuery': textQuery,
        'fields': fields,
        'locationBias': circleScope, // Prefer results near the user
        'language': 'en-AU',
        'maxResultCount': 20,
      };

      debugPrint('🧭 Calling Place.searchByText with request: $request');

      final promise = callMethod(placeStatics, 'searchByText', [jsify(request)]);

      promiseToFuture(promise).then((response) {
        debugPrint('📦 Received response from Google Places API (Text Search)');
        
        final List<PlaceResult> places = [];
        
        if (hasProperty(response, 'places')) {
          final dynamic rawPlaces = getProperty(response, 'places');
          List resultsList;
          if (rawPlaces is List) {
            resultsList = rawPlaces;
          } else if (rawPlaces is Iterable) {
            resultsList = List.from(rawPlaces);
          } else {
            resultsList = const [];
          }
          
          debugPrint('ℹ️ Raw results: ${resultsList.length} places');

          for (var i = 0; i < resultsList.length; i++) {
            try {
              final place = resultsList[i];
              
              final name = _extractText(getProperty(place, 'displayName')) ?? 'Unknown';
              final location = getProperty(place, 'location');
              if (location == null) continue;

              // Extract coordinates - try methods first, then properties
              double? lat;
              double? lng;
              try {
                final latFn = getProperty(location, 'lat');
                final lngFn = getProperty(location, 'lng');
                if (latFn != null && lngFn != null) {
                  lat = (callMethod(location, 'lat', []) as num?)?.toDouble();
                  lng = (callMethod(location, 'lng', []) as num?)?.toDouble();
                }
              } catch (e) {
                // Fallback
              }
              if (lat == null || lng == null) {
                lat = (getProperty(location, 'latitude') as num?)?.toDouble();
                lng = (getProperty(location, 'longitude') as num?)?.toDouble();
              }
              if (lat == null || lng == null) {
                lat = (getProperty(location, 'lat') as num?)?.toDouble();
                lng = (getProperty(location, 'lng') as num?)?.toDouble();
              }

              if (lat == null || lng == null) continue;
              
              final vicinity = _extractText(getProperty(place, 'formattedAddress')) ?? '';
              final rating = (getProperty(place, 'rating') as num?)?.toDouble() ?? 0.0;
              final userRatingsTotal = (getProperty(place, 'userRatingCount') as num?)?.toInt() ?? 0;
              final placeId = getProperty(place, 'id') as String? ?? '';
              
              final businessStatus = getProperty(place, 'businessStatus') as String?;
              final isOpen = businessStatus == 'OPERATIONAL';

              final distance = Geolocator.distanceBetween(latitude, longitude, lat, lng);

              PlaceCategory category = PlaceCategory.other;
              final primaryType = getProperty(place, 'primaryType') as String?;
              
              if (primaryType != null) {
                 if (primaryType.contains('park')) {
                    category = PlaceCategory.park;
                  } else if (primaryType.contains('pet_store')) {
                    category = PlaceCategory.petStore;
                  } else if (primaryType.contains('veterinary_care')) {
                    category = PlaceCategory.veterinary;
                  } else if (primaryType.contains('restaurant') || primaryType.contains('cafe')) {
                    category = PlaceCategory.restaurant;
                  }
              }

              String? photoReference;
              if (hasProperty(place, 'photos') && getProperty(place, 'photos') != null) {
                final photos = getProperty(place, 'photos') as List?;
                if (photos != null && photos.isNotEmpty) {
                  final firstPhoto = photos[0];
                  if (hasProperty(firstPhoto, 'name')) {
                     photoReference = getProperty(firstPhoto, 'name') as String?;
                  }
                }
              }

              places.add(PlaceResult(
                placeId: placeId,
                name: name,
                address: vicinity,
                latitude: lat,
                longitude: lng,
                rating: rating,
                userRatingsTotal: userRatingsTotal,
                isOpen: isOpen,
                category: category,
                distance: distance,
                photoReference: photoReference,
              ));
            } catch (e) {
              debugPrint('⚠️ Error parsing place ${i + 1}: $e');
            }
          }
        }

        completer.complete(PlaceSearchResult(
          places: places,
          nextPageToken: null,
        ));

      }).catchError((error) {
        debugPrint('❌ Google Places Text Search error: $error');
        completer.complete(PlaceSearchResult(places: [], nextPageToken: null));
      });

      return completer.future;
    } catch (e) {
      debugPrint('❌ Google Places Text Search setup error: $e');
      return PlaceSearchResult(places: [], nextPageToken: null);
    }
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

  // Get photo URL from photo reference
  static String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    // Return a placeholder image for now
    return 'https://via.placeholder.com/${maxWidth}x${(maxWidth * 0.6).round()}?text=Dog+Park';
  }

  static Future<void> _waitForGoogleMapsApi({bool verbose = false}) async {
    if (!kIsWeb) {
      return;
    }
    if (mapsApiReadyCompleter.isCompleted) {
      if (verbose) {
        debugPrint('✅ Google Maps API already initialised.');
      }
      return;
    }

    if (verbose) {
      debugPrint('⏳ Waiting for Google Maps API to load...');
    }

    await mapsApiReadyCompleter.future;

    if (verbose) {
      debugPrint('✅ Google Maps API is ready.');
    }
  }

static Object _buildCircleScope({
    required double latitude,
    required double longitude,
    required double radius,
  }) {
    // 1. Get the 'google.maps' namespace
    final Object google =
        _requireJsProperty(globalThis, 'google', 'google namespace not found');
    final Object maps =
        _requireJsProperty(google, 'maps', 'google.maps namespace not found');

    // 2. Get the 'Circle' constructor from the 'maps' namespace
    final Object circleConstructor =
        _requireJsProperty(maps, 'Circle', 'google.maps.Circle not found');

    // 3. Create the options object that the Circle constructor expects.
    //    This uses a 'LatLngLiteral' ({lat: ..., lng: ...}) for the center.
    final Object circleOptions = jsify({
      'center': {
        'lat': latitude,
        'lng': longitude,
      },
      'radius': radius,
    });

    // 4. Call the constructor (e.g., 'new google.maps.Circle(circleOptions)')
    //    and return the new Circle instance.
    return callConstructor(circleConstructor, [circleOptions]);
  }

  static String? _extractSuggestionDescription(dynamic suggestion) {
    if (suggestion == null) {
      return null;
    }

    if (hasProperty(suggestion, 'placePrediction')) {
      final placePrediction = getProperty(suggestion, 'placePrediction');

      if (placePrediction != null) {
        final structuredFormat = hasProperty(placePrediction, 'structuredFormat')
            ? getProperty(placePrediction, 'structuredFormat')
            : null;

        if (structuredFormat != null) {
          final mainText = hasProperty(structuredFormat, 'mainText')
              ? _extractText(getProperty(structuredFormat, 'mainText'))
              : null;
          final secondaryText = hasProperty(structuredFormat, 'secondaryText')
              ? _extractText(getProperty(structuredFormat, 'secondaryText'))
              : null;

          if (mainText != null && mainText.isNotEmpty) {
            if (secondaryText != null && secondaryText.isNotEmpty) {
              return '$mainText, $secondaryText';
            }
            return mainText;
          }
        }

        final String? fallbackText = hasProperty(placePrediction, 'text')
            ? _extractText(getProperty(placePrediction, 'text'))
            : null;

        if (fallbackText != null && fallbackText.isNotEmpty) {
          return fallbackText;
        }
      }
    }

    if (hasProperty(suggestion, 'queryPrediction')) {
      final queryPrediction = getProperty(suggestion, 'queryPrediction');
      final queryText = _extractText(hasProperty(queryPrediction, 'text')
          ? getProperty(queryPrediction, 'text')
          : queryPrediction);
      if (queryText != null && queryText.isNotEmpty) {
        return queryText;
      }
    }

    return null;
  }

  static String? _extractText(dynamic textObject) {
    if (textObject == null) {
      return null;
    }
    if (textObject is String) {
      return textObject;
    }
    if (hasProperty(textObject, 'text')) {
      final dynamic value = getProperty(textObject, 'text');
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  static Object _requireJsProperty(Object target, Object propertyName, String errorMessage) {
    if (!hasProperty(target, propertyName)) {
      throw StateError(errorMessage);
    }
    final value = getProperty(target, propertyName);
    if (value == null) {
      throw StateError(errorMessage);
    }
    return value;
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
  final bool isFeaturedPark; // Admin-added park from Supabase

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
    this.isFeaturedPark = false,
  });

  /// Check if this place is known to be dog-friendly
  /// Returns true for: featured parks (admin verified), dog parks, pet stores, vets
  /// Returns false for restaurants/cafes and other places (user should verify)
  bool get isDogFriendly {
    if (isFeaturedPark) return true;
    if (category == PlaceCategory.park) return true;
    if (category == PlaceCategory.petStore) return true;
    if (category == PlaceCategory.veterinary) return true;
    // Restaurants and "other" need verification - not automatically dog-friendly
    return false;
  }
  
  /// Status text for dog-friendliness
  String get dogFriendlyStatus {
    if (isFeaturedPark) return '✓ Verified Dog-Friendly';
    if (isDogFriendly) return '🐕 Dog-Friendly';
    return 'Check if dog-friendly';
  }

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

// Pagination result wrapper
class PlaceSearchResult {
  final List<PlaceResult> places;
  final String? nextPageToken;

  PlaceSearchResult({
    required this.places,
    this.nextPageToken,
  });

  bool get hasMore => nextPageToken != null;
}
