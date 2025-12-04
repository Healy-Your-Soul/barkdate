import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/park_service.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/models/checkin.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/firebase_options.dart';
import 'package:barkdate/widgets/checkin_button.dart';
import 'dart:async';
import 'package:barkdate/widgets/app_bottom_sheet.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/widgets/app_card.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  bool _loading = true;
  List<Map<String, dynamic>> _nearbyParks = [];
  List<Map<String, dynamic>> _featuredParks = [];
  final Set<Marker> _markers = {};
  Map<String, int> _dogCounts = {};
  StreamSubscription? _dogCountSubscription;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<PlaceResult> _searchResults = [];
  bool _showingSearchResults = false;
  CheckIn? _activeCheckIn;
  final ScrollController _scrollController = ScrollController();
  bool _showFAB = true;
  int _selectedRadius = 5000; // Default radius in meters
  final List<int> _radiusOptions = [500, 1000, 5000, 10000, 20000, 50000];
  bool _showSearchSuggestions = false;
  final FocusNode _searchFocusNode = FocusNode();
  PlaceCategory? _selectedCategory; // null means "All"
  
  // Pagination
  String? _nextPageToken;
  bool _isLoadingMore = false;
  String? _lastSearchQuery;
  
  // Smart search suggestions
  final List<String> _searchSuggestions = [
    'dog parks near me',
    'dog friendly cafes',
    'dog friendly restaurants',
    'pet stores',
    'veterinarians',
    'dog groomers',
    'dog beaches',
    'dog friendly hotels',
  ];

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupRealTimeDogCounts();
    _loadActiveCheckIn();
    _setupScrollListener();
    _setupSearchListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dogCountSubscription?.cancel();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _setupSearchListener() {
    _searchFocusNode.addListener(() {
      setState(() {
        _showSearchSuggestions = _searchFocusNode.hasFocus && _searchController.text.isEmpty;
      });
    });
    
    _searchController.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _showSearchSuggestions = _searchController.text.isEmpty;
        });
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Show FAB when scrolling up, hide when scrolling down
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFAB) setState(() => _showFAB = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFAB) setState(() => _showFAB = true);
      }
    });
  }

  void _setupRealTimeDogCounts() {
    try {
      _dogCountSubscription = BarkDateUserService.getDogCountUpdates()
          .listen((counts) {
        if (mounted) {
          setState(() {
            _dogCounts = counts;
          });
          _updateMarkers();
        }
      });
    } catch (e) {
      debugPrint('Error setting up real-time dog counts: $e');
    }
  }

  Future<void> _initializeMap() async {
    try {
      // Get location permission and current location
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _setDefaultLocation();
          return;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _setDefaultLocation();
          return;
        }
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      } else {
        _setDefaultLocation();
      }

      // Load parks and featured parks
      if (_currentLocation != null) {
        await _loadParksData();
      }

      _updateMarkers();
    } catch (e) {
      debugPrint('Map initialization failed: $e');
      _setDefaultLocation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadActiveCheckIn() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted) {
        setState(() {
          _activeCheckIn = checkIn;
        });
      }
    } catch (e) {
      debugPrint('Error loading active check-in: $e');
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentLocation = const LatLng(40.7829, -73.9654); // NYC default
    });
  }

  Future<void> _loadParksData() async {
    if (_currentLocation == null) return;

    try {
      debugPrint('🔍 Loading dog-friendly places from PlacesService (via Maps API)...');
      
      // Use the existing PlacesService which works on web
      // It uses the Google Maps JavaScript API already loaded
      final result = await PlacesService.searchDogFriendlyPlaces(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radius: _selectedRadius, // Use selected radius
      );
      
      final googlePlaces = result.places;
      debugPrint('✅ Found ${googlePlaces.length} dog-friendly places');
      
      // Convert to map format
      final placesData = googlePlaces.map((place) => {
        'id': place.placeId,
        'name': place.name,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'description': '',
        'address': place.address,
        'rating': place.rating,
        'source': 'google_places',
        'distance': place.distance,
      }).toList();
      
      // Also load featured parks from database (as backup/favorites)
      final featuredData = await ParkService.getFeaturedParks();
      final featured = featuredData.map((park) => {
        'id': park.id,
        'name': park.name,
        'latitude': park.latitude,
        'longitude': park.longitude,
        'description': park.description,
        'amenities': park.amenities,
        'rating': park.rating,
        'address': park.address,
        'source': 'database',
      }).toList();
      
      // Combine Google Places results with database parks
      final allPlaces = [...placesData, ...featured];
      
      // Get current dog counts from database
      Map<String, int> counts = {};
      try {
        counts = await BarkDateUserService.getCurrentDogCounts();
      } catch (e) {
        debugPrint('Error loading dog counts: $e');
      }

      if (mounted) {
        setState(() {
          _nearbyParks = allPlaces; // Now includes Google Places results!
          _featuredParks = featured;
          _dogCounts = counts;
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('Failed to load parks data: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    if (_showingSearchResults) {
      // Show search results with correct iconography
      for (int i = 0; i < _searchResults.length; i++) {
        final place = _searchResults[i];
        
        // Apply category filter
        if (_selectedCategory != null && place.category != _selectedCategory) {
          continue;
        }
        
        BitmapDescriptor markerIcon;
        switch (place.category) {
          case PlaceCategory.park:
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
            break;
          case PlaceCategory.petStore:
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
            break;
          case PlaceCategory.veterinary:
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            break;
          case PlaceCategory.restaurant:
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
            break;
          case PlaceCategory.other:
          default:
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        }
        _markers.add(Marker(
          markerId: MarkerId('search_$i'),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: '${place.distanceText} • ${place.rating}⭐',
          ),
          icon: markerIcon,
          onTap: () => _showPlaceDetails(place),
        ));
      }
    } else {
      // Show regular parks and other places with correct iconography
      for (final park in _nearbyParks) {
        // Apply category filter
        if (_selectedCategory != null && park['category'] != _selectedCategory) {
          continue;
        }
        
        final dogCount = _dogCounts[park['id']] ?? 0;
        BitmapDescriptor markerIcon;
        if (park['source'] == 'google_places' && park['category'] != null) {
          switch (park['category']) {
            case PlaceCategory.park:
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
              break;
            case PlaceCategory.petStore:
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
              break;
            case PlaceCategory.veterinary:
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
              break;
            case PlaceCategory.restaurant:
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
              break;
            case PlaceCategory.other:
            default:
              markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          }
        } else {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        }
        _markers.add(Marker(
          markerId: MarkerId('park_${park['id']}'),
          position: LatLng(park['latitude'], park['longitude']),
          infoWindow: InfoWindow(
            title: park['name'],
            snippet: dogCount > 0 ? '$dogCount dogs active' : 'No dogs currently',
          ),
          icon: markerIcon,
          onTap: () => _showParkDetails(park),
        ));
      }

      // Featured parks - only show if no category filter or if they match the filter
      for (final park in _featuredParks) {
        // Apply category filter (featured parks are typically parks)
        if (_selectedCategory != null && _selectedCategory != PlaceCategory.park) {
          continue;
        }
        
        final dogCount = _dogCounts[park['id']] ?? 0;
        _markers.add(Marker(
          markerId: MarkerId('featured_${park['id']}'),
          position: LatLng(park['latitude'], park['longitude']),
          infoWindow: InfoWindow(
            title: '⭐ ${park['name']}',
            snippet: dogCount > 0 ? '$dogCount dogs active' : 'Featured park',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _showFeaturedParkDetails(park),
        ));
      }
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _searchPlaces(String query) async {
    if (_currentLocation == null || query.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _lastSearchQuery = query;
      _nextPageToken = null; // Reset pagination for new search
    });
    
    try {
      debugPrint('🔍 Searching for: "$query"');
      
      // Use the existing PlacesService (works on web via Google Maps JS API)
      final result = await PlacesService.searchDogFriendlyPlaces(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        keyword: query,
        radius: _selectedRadius, // Use selected radius
      );
      
      debugPrint('✅ Found ${result.places.length} places for "$query"');
      debugPrint('📄 Has more pages: ${result.hasMore}');
      
      setState(() {
        _searchResults = result.places;
        _showingSearchResults = true;
        _nextPageToken = result.nextPageToken;
      });
      _updateMarkers();
    } catch (e) {
      debugPrint('❌ Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMoreResults() async {
    if (_currentLocation == null || _nextPageToken == null || _isLoadingMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      debugPrint('📄 Loading more results (page token: $_nextPageToken)...');
      
      final result = await PlacesService.searchDogFriendlyPlaces(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        keyword: _lastSearchQuery,
        radius: _selectedRadius,
        pageToken: _nextPageToken,
      );
      
      debugPrint('✅ Loaded ${result.places.length} more places');
      debugPrint('📄 Has more pages: ${result.hasMore}');
      
      setState(() {
        _searchResults.addAll(result.places);
        _nextPageToken = result.nextPageToken;
      });
      _updateMarkers();
    } catch (e) {
      debugPrint('❌ Load more error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more results: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showingSearchResults = false;
      _searchResults.clear();
      _nextPageToken = null;
      _lastSearchQuery = null;
    });
    _updateMarkers();
  }
  
  void _applyFilter() {
    // When a filter is applied, we should trigger a new search for that category
    // if we are not already showing search results for that specific category.
    String categoryKeyword = '';
    bool shouldSearch = true;

    switch (_selectedCategory) {
      case PlaceCategory.park:
        categoryKeyword = 'dog park';
        break;
      case PlaceCategory.restaurant:
        categoryKeyword = 'dog friendly cafe restaurant';
        break;
      case PlaceCategory.petStore:
        categoryKeyword = 'pet store';
        break;
      case PlaceCategory.veterinary:
        categoryKeyword = 'veterinary vet';
        break;
      case null: // "All" is selected
      case PlaceCategory.other:
        shouldSearch = false; // Don't trigger a new search, just clear filters
        break;
    }
    
    // If "All" is selected, clear the search results and show the default parks
    if (_selectedCategory == null) {
      _clearSearch();
      return;
    }

    // Only trigger a new search if the keyword is different from the last one
    if (shouldSearch && categoryKeyword.isNotEmpty && _lastSearchQuery != categoryKeyword) {
      _searchController.text = categoryKeyword; // Update search bar text
      _searchPlaces(categoryKeyword);
    } else {
      // If not searching, just update the markers to filter the existing view
      _updateMarkers();
    }
  }

  Future<void> _searchInArea() async {
    if (_mapController == null) return;
    final bounds = await _mapController!.getVisibleRegion();
    // Use the center of bounds and radius as the diagonal distance
    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final diagonalMeters = Geolocator.distanceBetween(
      bounds.northeast.latitude, bounds.northeast.longitude,
      bounds.southwest.latitude, bounds.southwest.longitude,
    );
    final calculatedRadius = (diagonalMeters / 2).clamp(500, 50000).toInt();
    
    // Find the closest valid radius option
    int closestRadius = _radiusOptions.reduce((a, b) => 
      (a - calculatedRadius).abs() < (b - calculatedRadius).abs() ? a : b
    );
    
    setState(() {
      _currentLocation = LatLng(centerLat, centerLng);
      _selectedRadius = closestRadius;
    });
    await _loadParksData();
  }

  Future<void> _centerOnMyLocation() async {
    if (_currentLocation == null || _mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _currentLocation!, zoom: 14),
    ));
  }

  Future<void> _fetchLiveSuggestions(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _showSearchSuggestions = false;
        _searchSuggestions.clear();
      });
      return;
    }
    
    final apiKey = DefaultFirebaseOptions.web.apiKey;
    double? lat;
    double? lng;
    if (_currentLocation != null) {
      lat = _currentLocation!.latitude;
      lng = _currentLocation!.longitude;
    }
    
    try {
      final suggestions = await PlacesService.getAutocompleteSuggestions(
        input: query,
        apiKey: apiKey,
        latitude: lat,
        longitude: lng,
        types: 'establishment',
      );
      
      if (mounted) {
        setState(() {
          _showSearchSuggestions = suggestions.isNotEmpty;
          _searchSuggestions.clear();
          _searchSuggestions.addAll(suggestions);
        });
        debugPrint('🌐 Google suggestions: $_searchSuggestions');
      }
    } catch (e) {
      debugPrint('❌ Google Autocomplete failed: $e');
      // Fallback to empty suggestions on error
      if (mounted) {
        setState(() {
          _showSearchSuggestions = false;
          _searchSuggestions.clear();
        });
      }
    }
  }

  List<String> _generateSuggestions(String query) {
    final lowerQuery = query.toLowerCase().trim();
    final suggestions = <String>[];
    
    // Predefined smart suggestions (Google-style)
    final predefinedSuggestions = [
      'dog park near me',
      'dog-friendly cafes',
      'pet stores',
      'veterinary clinics',
      'dog beach',
      'dog-friendly restaurants',
      'off-leash dog areas',
      'dog daycare',
      'dog grooming',
      'puppy training classes',
    ];
    
    // Add matching predefined suggestions
    for (final suggestion in predefinedSuggestions) {
      if (suggestion.toLowerCase().contains(lowerQuery)) {
        suggestions.add(suggestion);
      }
    }
    
    // Add suggestions based on loaded places (if available)
    for (final place in _searchResults) {
      if (place.name.toLowerCase().contains(lowerQuery)) {
        if (!suggestions.contains(place.name)) {
          suggestions.add(place.name);
        }
      }
    }
    
    // If no suggestions, add helpful defaults
    if (suggestions.isEmpty) {
      if (lowerQuery.length >= 2) {
        suggestions.addAll([
          'dog park near me',
          'pet-friendly places near me',
          'dog cafes',
        ]);
      }
    }
    
    // Limit to 8 suggestions (Google-like)
    return suggestions.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showingSearchResults ? 'Search Results' : 'Dog Parks'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location, color: Theme.of(context).colorScheme.onPrimaryContainer),
            onPressed: _centerOnMyLocation,
            tooltip: 'My location',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Dismiss suggestions when tapping outside
                if (_showSearchSuggestions) {
                  setState(() {
                    _showSearchSuggestions = false;
                  });
                  _searchFocusNode.unfocus();
                }
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Check-in status banner
                      CheckInStatusBanner(),
                      // Search bar and radius selector
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Search dog parks, cafes, stores...',
                                  prefixIcon: const Icon(Icons.search),
                                suffixIcon: _isSearching
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: _clearSearch,
                                          )
                                        : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onChanged: (value) {
                                debugPrint('🔍 Search text changed: "$value"');
                                if (value.isEmpty) {
                                  setState(() {
                                    _showSearchSuggestions = false;
                                    _searchSuggestions.clear();
                                  });
                                } else if (value.length >= 2) {
                                  _fetchLiveSuggestions(value);
                                }
                              },
                              onSubmitted: _searchPlaces,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _selectedRadius,
                            items: _radiusOptions.map((radius) {
                              return DropdownMenuItem<int>(
                                value: radius,
                                child: Text('${radius >= 1000 ? (radius ~/ 1000).toString() + "km" : "$radius m"}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedRadius = value;
                                });
                                // Reload parks with new radius
                                _loadParksData();
                              }
                            },
                            underline: Container(),
                            style: Theme.of(context).textTheme.bodyMedium,
                            icon: const Icon(Icons.circle, size: 16),
                            dropdownColor: Theme.of(context).colorScheme.surface,
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            text: 'Search',
                            onPressed: _isSearching ? null : () => _searchPlaces(_searchController.text),
                          ),
                        ],
                      ),
                    ),
                // Filter chips for place categories
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      FilterChip(
                        label: const Text('All', style: TextStyle(fontSize: 13)),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = null;
                          });
                          _applyFilter();
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '${PlaceCategory.park.icon} Parks',
                          style: const TextStyle(fontSize: 13),
                        ),
                        selected: _selectedCategory == PlaceCategory.park,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = PlaceCategory.park;
                          });
                          _applyFilter();
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '${PlaceCategory.restaurant.icon} Cafes',
                          style: const TextStyle(fontSize: 13),
                        ),
                        selected: _selectedCategory == PlaceCategory.restaurant,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = PlaceCategory.restaurant;
                          });
                          _applyFilter();
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '${PlaceCategory.petStore.icon} Stores',
                          style: const TextStyle(fontSize: 13),
                        ),
                        selected: _selectedCategory == PlaceCategory.petStore,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = PlaceCategory.petStore;
                          });
                          _applyFilter();
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '${PlaceCategory.veterinary.icon} Vets',
                          style: const TextStyle(fontSize: 13),
                        ),
                        selected: _selectedCategory == PlaceCategory.veterinary,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = PlaceCategory.veterinary;
                          });
                          _applyFilter();
                        },
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ],
                  ),
                ),
                // Map with overlaid "Search this area" button
                SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? const LatLng(40.7829, -73.9654),
                          zoom: 12,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        markers: _markers,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                      ),
                      // "Search this area" button overlaid on map
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              onTap: _searchInArea,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.explore, size: 18, color: Theme.of(context).colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Search this area',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                    // Parks list
                    Expanded(
                      child: _showingSearchResults 
                          ? _buildSearchResultsList() 
                          : _buildParksList(),
                    ),
                  ],
                ),
                // Smart search suggestions overlay - positioned absolutely on top
                if (_showSearchSuggestions)
                  Positioned(
                    top: 130, // Below search bar (CheckInBanner ~50 + SearchBar ~80)
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surface,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _searchSuggestions[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  debugPrint('🔍 Suggestion tapped: $suggestion');
                                  setState(() {
                                    _searchController.text = suggestion;
                                    _showSearchSuggestions = false;
                                  });
                                  _searchFocusNode.unfocus();
                                  _searchPlaces(suggestion);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                  decoration: BoxDecoration(
                                    border: index < _searchSuggestions.length - 1
                                        ? Border(
                                            bottom: BorderSide(
                                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                                              width: 1,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          suggestion,
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      floatingActionButton: _activeCheckIn == null 
          ? AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: _showFAB ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showFAB ? 1.0 : 0.0,
                child: FloatingActionButton.extended(
                  onPressed: _showCheckInOptions,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.pets),
                  label: const Text('Check In'),
                ),
              ),
            )
          : null,
    );
  }

  void _showCheckInOptions() {
    AppBottomSheet.show(
      context: context,
      title: 'Check In at a Park',
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _nearbyParks.length,
        itemBuilder: (context, index) {
          final park = _nearbyParks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () {
                Navigator.pop(context);
                _checkInAtPark(park);
              },
              child: Row(
                children: [
                  // Show correct icon for place type
                  park['category'] == PlaceCategory.park
                      ? const Icon(Icons.park)
                      : park['category'] == PlaceCategory.restaurant
                          ? const Icon(Icons.local_cafe)
                          : park['category'] == PlaceCategory.petStore
                              ? const Icon(Icons.store)
                              : park['category'] == PlaceCategory.veterinary
                                  ? const Icon(Icons.local_hospital)
                                  : const Icon(Icons.location_on),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(park['name'] ?? 'Unknown Park',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(park['address'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _checkInAtPark(Map<String, dynamic> park) async {
    final checkIn = await CheckInService.checkInAtPark(
      parkId: park['id'],
      parkName: park['name'] ?? 'Unknown Park',
      latitude: park['latitude'],
      longitude: park['longitude'],
    );

    if (checkIn != null) {
      setState(() {
        _activeCheckIn = checkIn;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Woof! I\'m checked in at ${park['name']}! 🐕'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      
      // Refresh dog counts
      _loadParksData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to check in. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildParksList() {
    final allParks = [..._featuredParks, ..._nearbyParks];
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: allParks.length,
      itemBuilder: (context, index) {
        final park = allParks[index];
        final isFeatured = index < _featuredParks.length;
        final dogCount = _dogCounts[park['id']] ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFeatured ? Colors.orange : const Color(0xFF2E7D32),
              child: Icon(
                isFeatured ? Icons.star : Icons.park,
                color: Colors.white,
              ),
            ),
            title: Text(
              isFeatured ? '⭐ ${park['name']}' : park['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (park['distance'] != null)
                  Text('${(park['distance'] as double).toStringAsFixed(1)} km away'),
                if (dogCount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🐕 $dogCount dogs active',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => isFeatured ? _showFeaturedParkDetails(park) : _showParkDetails(park),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    // Filter results based on selected category
    final filteredResults = _selectedCategory == null
        ? _searchResults
        : _searchResults.where((place) => place.category == _selectedCategory).toList();
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredResults.length + (_nextPageToken != null ? 1 : 0), // +1 for Load More button
      itemBuilder: (context, index) {
        // Load More button at the end
        if (index == filteredResults.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _loadMoreResults,
                      icon: const Icon(Icons.expand_more),
                      label: Text('Load More (${_searchResults.length} of up to 60)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
            ),
          );
        }
        
        final place = filteredResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                place.category.icon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Text(place.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.address,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${place.distanceText} • ',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (place.rating > 0) ...[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(' ${place.rating.toStringAsFixed(1)}'),
                    ],
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPlaceDetails(place),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _showPlaceDetails(PlaceResult place) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and name
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 28,
                          child: Text(
                            place.category.icon,
                            style: const TextStyle(fontSize: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                place.category.displayName,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Rating and status row
                    Row(
                      children: [
                        if (place.rating > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  place.rating.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (place.userRatingsTotal > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${place.userRatingsTotal})',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: place.isOpen ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                place.isOpen ? Icons.check_circle : Icons.cancel,
                                color: place.isOpen ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                place.isOpen ? 'Open Now' : 'Closed',
                                style: TextStyle(
                                  color: place.isOpen ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Address section
                    _buildInfoRow(
                      context,
                      Icons.place,
                      'Address',
                      place.address,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Distance section
                    _buildInfoRow(
                      context,
                      Icons.location_on,
                      'Distance',
                      place.distanceText,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Opening hours (mock data for now)
                    _buildInfoRow(
                      context,
                      Icons.access_time,
                      'Hours',
                      'Mon-Fri: 8:00 AM - 6:00 PM\nSat-Sun: 9:00 AM - 5:00 PM',
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone (mock data)
                    InkWell(
                      onTap: () {
                        final uri = Uri.parse('tel:+15551234567');
                        launchUrl(uri);
                      },
                      child: _buildInfoRow(
                        context,
                        Icons.phone,
                        'Phone',
                        '+1 (555) 123-4567',
                        isLink: true,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Website (mock data)
                    InkWell(
                      onTap: () {
                        final uri = Uri.parse('https://example.com');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: _buildInfoRow(
                        context,
                        Icons.language,
                        'Website',
                        'Visit website',
                        isLink: true,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Reviews section
                    Text(
                      'Reviews',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Mock reviews
                    _buildReviewCard(
                      context,
                      'Sarah M.',
                      5,
                      'Great dog-friendly spot! My pup loved it here. Staff was very accommodating.',
                      '2 days ago',
                    ),
                    const SizedBox(height: 12),
                    _buildReviewCard(
                      context,
                      'John D.',
                      4,
                      'Nice place, good atmosphere. Would recommend for dog owners!',
                      '1 week ago',
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _checkInAtPark({
                                'id': 'place_${place.latitude}_${place.longitude}',
                                'name': place.name,
                                'latitude': place.latitude,
                                'longitude': place.longitude,
                                'category': place.category,
                              });
                            },
                            icon: const Icon(Icons.pets),
                            label: const Text('Check In'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final uri = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}');
                              launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.directions),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isLink ? Theme.of(context).colorScheme.primary : null,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReviewCard(BuildContext context, String author, int rating, String text, String time) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  author[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showParkDetails(Map<String, dynamic> park) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final dogCount = _dogCounts[park['id']] ?? 0;
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(Icons.park, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          park['name'] ?? 'Dog Park',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dog Park',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions),
                    onPressed: () {
                      final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${park['latitude']},${park['longitude']}');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Text(
                      dogCount > 0 
                          ? '$dogCount dogs currently active at this park'
                          : 'No dogs currently at this park',
                      style: const TextStyle(color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _checkInAtPark(park);
                      },
                      icon: const Icon(Icons.pets),
                      label: const Text('Check In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${park['latitude']},${park['longitude']}');
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFeaturedParkDetails(Map<String, dynamic> park) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final dogCount = _dogCounts[park['id']] ?? 0;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.star, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              park['name'] ?? 'Featured Park',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Featured Dog Park',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.directions),
                        onPressed: () {
                          final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${park['latitude']},${park['longitude']}');
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Rating and info
                  if (park['rating'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          (park['rating'] as double).toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Dog count
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pets, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        Text(
                          dogCount > 0 
                              ? '$dogCount dogs currently active'
                              : 'No dogs currently at this park',
                          style: const TextStyle(color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                  
                  // Description
                  if (park['description'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'About this park',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      park['description'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  
                  // Amenities
                  if (park['amenities'] != null && (park['amenities'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Amenities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (park['amenities'] as List<dynamic>)
                          .map((amenity) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  amenity.toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final uri = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${park['latitude']},${park['longitude']}');
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.directions),
                          label: const Text('Directions'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
