import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/park_service.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _setupRealTimeDogCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dogCountSubscription?.cancel();
    super.dispose();
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

  void _setDefaultLocation() {
    setState(() {
      _currentLocation = const LatLng(40.7829, -73.9654); // NYC default
    });
  }

  Future<void> _loadParksData() async {
    if (_currentLocation == null) return;

    try {
      // Load nearby parks
      final parks = await ParkService.getNearbyParks(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );
      
      // Load featured parks and convert to Map format
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
      }).toList();
      
      // Get current dog counts
      Map<String, int> counts = {};
      try {
        counts = await BarkDateUserService.getCurrentDogCounts();
      } catch (e) {
        debugPrint('Error loading dog counts: $e');
      }

      if (mounted) {
        setState(() {
          _nearbyParks = parks;
          _featuredParks = featured;
          _dogCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Failed to load parks data: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    if (_showingSearchResults) {
      // Show search results
      for (int i = 0; i < _searchResults.length; i++) {
        final place = _searchResults[i];
        _markers.add(Marker(
          markerId: MarkerId('search_$i'),
          position: LatLng(place.latitude, place.longitude),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: '${place.distanceText} • ${place.rating}⭐',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          onTap: () => _showPlaceDetails(place),
        ));
      }
    } else {
      // Show regular parks
      for (final park in _nearbyParks) {
        final dogCount = _dogCounts[park['id']] ?? 0;
        _markers.add(Marker(
          markerId: MarkerId('park_${park['id']}'),
          position: LatLng(park['latitude'], park['longitude']),
          infoWindow: InfoWindow(
            title: park['name'],
            snippet: dogCount > 0 ? '$dogCount dogs active' : 'No dogs currently',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showParkDetails(park),
        ));
      }

      // Show featured parks with special markers
      for (final park in _featuredParks) {
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
    
    setState(() => _isSearching = true);
    
    try {
      final results = await PlacesService.searchDogFriendlyPlaces(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        keyword: query,
      );
      
      setState(() {
        _searchResults = results;
        _showingSearchResults = true;
      });
      _updateMarkers();
    } catch (e) {
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

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showingSearchResults = false;
      _searchResults.clear();
    });
    _updateMarkers();
  }

  Future<void> _centerOnMyLocation() async {
    if (_currentLocation == null || _mapController == null) return;
    await _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _currentLocation!, zoom: 14),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showingSearchResults ? 'Search Results' : 'Dog Parks'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMyLocation,
            tooltip: 'My location',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
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
                          onSubmitted: _searchPlaces,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : () => _searchPlaces(_searchController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ),
                // Map
                SizedBox(
                  height: 300,
                  child: GoogleMap(
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
                ),
                // Parks list
                Expanded(
                  child: _showingSearchResults ? _buildSearchResultsList() : _buildParksList(),
                ),
              ],
            ),
    );
  }

  Widget _buildParksList() {
    final allParks = [..._featuredParks, ..._nearbyParks];
    
    return ListView.builder(
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final place = _searchResults[index];
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
                Text(place.address),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${place.distanceText} • '),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
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
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          place.category.displayName,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.directions),
                    onPressed: () {
                      final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Rating and distance
              Row(
                children: [
                  if (place.rating > 0) ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          place.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (place.userRatingsTotal > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${place.userRatingsTotal})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 4),
                      Text(place.distanceText),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: place.isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      place.isOpen ? 'Open' : 'Closed',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                ),
              ),
            ],
          ),
        );
      },
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
