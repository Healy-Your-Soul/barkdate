import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../services/park_service.dart';
import '../services/places_service.dart';
import '../models/featured_park.dart';
import 'admin_screen.dart';
import 'dart:async';

class EnhancedMapScreen extends StatefulWidget {
  const EnhancedMapScreen({super.key});

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen> {
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentLocation;
  bool _loading = true;
  bool _isCheckedIn = false;
  final Set<Marker> _markers = {};

  // Enhanced features
  List<Map<String, dynamic>> _nearbyParks = [];
  List<FeaturedPark> _featuredParks = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<PlaceResult> _searchResults = [];
  bool _showingSearchResults = false;
  bool _showOnlyFeatured = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      // Get location permission and current location
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
      }

      // Load parks and featured parks
      if (_currentLocation != null) {
        await _loadParksData();
      }

      _updateMarkers();
    } catch (e) {
      debugPrint('Map initialization failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadParksData() async {
    if (_currentLocation == null) return;

    try {
      // Load nearby parks with distance sorting
      final parks = await ParkService.getNearbyParks(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );

      final featured = await ParkService.getFeaturedParks();

      if (mounted) {
        setState(() {
          _nearbyParks = parks;
          _featuredParks = featured;
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
      for (final place in _searchResults) {
        _markers.add(Marker(
          markerId: MarkerId('search_${place.placeId}'),
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
      // Show regular parks (unless filtered to featured only)
      if (!_showOnlyFeatured) {
        for (final park in _nearbyParks) {
          _markers.add(Marker(
            markerId: MarkerId('park_${park['id']}'),
            position: LatLng(park['latitude'], park['longitude']),
            infoWindow: InfoWindow(
              title: park['name'],
              snippet: park['address'] ?? 'Dog park nearby',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            onTap: () => _showParkDetails(park),
          ));
        }
      }

      // Show featured parks with special markers
      for (final park in _featuredParks) {
        _markers.add(Marker(
          markerId: MarkerId('featured_${park.id}'),
          position: LatLng(park.latitude, park.longitude),
          infoWindow: InfoWindow(
            title: '⭐ ${park.name}',
            snippet: 'Featured park • ${park.rating}⭐',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _showFeaturedParkDetails(park),
        ));
      }
    }

    // Add current location marker
    if (_currentLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (_currentLocation == null || query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final result = await PlacesService.searchDogFriendlyPlaces(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        keyword: query,
      );

      setState(() {
        _searchResults = result.places;
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
      _searchResults = [];
    });
    _updateMarkers();
  }

  void _showPlaceDetails(PlaceResult place) {
    showBottomSheet(
      context: context,
      builder: (context) => PlaceDetailsSheet(place: place),
    );
  }

  void _showParkDetails(Map<String, dynamic> park) {
    showBottomSheet(
      context: context,
      builder: (context) => ParkDetailsSheet(park: park),
    );
  }

  void _showFeaturedParkDetails(FeaturedPark park) {
    showBottomSheet(
      context: context,
      builder: (context) => FeaturedParkDetailsSheet(park: park),
    );
  }

  void _toggleCheckIn() {
    setState(() {
      _isCheckedIn = !_isCheckedIn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isCheckedIn ? 'Checked in successfully!' : 'Checked out'),
        backgroundColor: _isCheckedIn ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _loading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target:
                        _currentLocation ?? const LatLng(37.7749, -122.4194),
                    zoom: 14.0,
                  ),
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_currentLocation != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
                      );
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),

          // Search Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for dog parks...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _showingSearchResults
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: _searchPlaces,
              ),
            ),
          ),

          // Filter Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            child: Column(
              children: [
                FilterButton(
                  icon: Icons.star,
                  label: 'Featured',
                  isSelected: _showOnlyFeatured,
                  onTap: () {
                    setState(() {
                      _showOnlyFeatured = !_showOnlyFeatured;
                    });
                    _updateMarkers();
                  },
                ),
                const SizedBox(height: 8),
                FilterButton(
                  icon: Icons.my_location,
                  label: 'My Location',
                  onTap: () {
                    if (_currentLocation != null) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Admin Button (show only for admin users)
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminScreen(),
                  ),
                );
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.admin_panel_settings),
            ),
          ),

          // Check-in/Check-out Button
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _toggleCheckIn,
              backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
              icon: Icon(_isCheckedIn ? Icons.exit_to_app : Icons.location_on),
              label: Text(_isCheckedIn ? 'Check Out' : 'Check In'),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail Sheets
class PlaceDetailsSheet extends StatelessWidget {
  final PlaceResult place;

  const PlaceDetailsSheet({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${place.rating}⭐ • ${place.distanceText}'),
          const SizedBox(height: 8),
          Text(place.address),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to featured parks
            },
            child: const Text('Add to Featured'),
          ),
        ],
      ),
    );
  }
}

class ParkDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> park;

  const ParkDetailsSheet({super.key, required this.park});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            park['name'] ?? 'Unknown Park',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(park['address'] ?? ''),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Check In Here'),
          ),
        ],
      ),
    );
  }
}

class FeaturedParkDetailsSheet extends StatelessWidget {
  final FeaturedPark park;

  const FeaturedParkDetailsSheet({super.key, required this.park});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  park.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${park.rating}⭐ • ${park.reviewCount} reviews'),
          const SizedBox(height: 8),
          Text(park.address ?? 'No address provided'),
          const SizedBox(height: 8),
          Text(park.description),
          const SizedBox(height: 16),
          if (park.amenities.isNotEmpty) ...[
            const Text('Amenities:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: park.amenities
                  .map((amenity) => Chip(
                        label:
                            Text(amenity, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Check In Here'),
          ),
        ],
      ),
    );
  }
}
