import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/park_service.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'dart:async';
import 'dart:math';

class EnhancedMapScreen extends StatefulWidget {
  const EnhancedMapScreen({super.key});

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng? _currentLocation;
  bool _loading = true;
  List<Map<String, dynamic>> _nearbyParks = [];
  List<Map<String, dynamic>> _featuredParks = [];
  Set<Marker> _markers = {};
  Map<String, int> _parkDogCounts = {};
  StreamSubscription? _dogCountSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _setupRealTimeDogCounts();
  }

  @override
  void dispose() {
    _dogCountSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeDogCounts() {
    _dogCountSubscription = BarkDateUserService.getDogCountUpdates()
        .listen((counts) {
      setState(() {
        _parkDogCounts = counts;
      });
      _updateMarkersWithCounts();
    });
  }

  Future<void> _initializeLocation() async {
    try {
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
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
        
        await _loadNearbyParks();
        await _loadFeaturedParks();
        await _loadInitialDogCounts();
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadNearbyParks() async {
    if (_currentLocation == null) return;

    try {
      final parks = await ParkService.getNearbyParks(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 10,
      );
      
      setState(() {
        _nearbyParks = parks;
      });
      
      _updateMarkersWithParks();
    } catch (e) {
      debugPrint('Error loading nearby parks: $e');
    }
  }

  Future<void> _loadFeaturedParks() async {
    try {
      final featured = await ParkService.getFeaturedParks();
      setState(() {
        _featuredParks = featured;
      });
      _updateMarkersWithParks();
    } catch (e) {
      debugPrint('Error loading featured parks: $e');
    }
  }

  Future<void> _loadInitialDogCounts() async {
    try {
      final counts = await BarkDateUserService.getCurrentDogCounts();
      setState(() {
        _parkDogCounts = counts;
      });
    } catch (e) {
      debugPrint('Error loading dog counts: $e');
    }
  }

  void _updateMarkersWithParks() {
    Set<Marker> newMarkers = {};

    // Add nearby parks markers (regular parks)
    for (var park in _nearbyParks) {
      final dogCount = _parkDogCounts[park['id']] ?? 0;
      newMarkers.add(
        Marker(
          markerId: MarkerId('park_${park['id']}'),
          position: LatLng(park['latitude'], park['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: park['name'],
            snippet: dogCount > 0 ? '$dogCount ${dogCount == 1 ? 'dog' : 'dogs'} here now' : 'No dogs currently',
          ),
          onTap: () => _showParkDetails(park, dogCount, false),
        ),
      );
    }

    // Add featured parks markers (admin-curated)
    for (var park in _featuredParks) {
      final dogCount = _parkDogCounts[park['id']] ?? 0;
      newMarkers.add(
        Marker(
          markerId: MarkerId('featured_${park['id']}'),
          position: LatLng(park['latitude'], park['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '⭐ ${park['name']}',
            snippet: dogCount > 0 ? '$dogCount ${dogCount == 1 ? 'dog' : 'dogs'} here now' : 'Featured park',
          ),
          onTap: () => _showParkDetails(park, dogCount, true),
        ),
      );
    }

    // Add current location marker
    if (_currentLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _updateMarkersWithCounts() {
    _updateMarkersWithParks();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double lat1Rad = point1.latitude * (pi / 180);
    double lat2Rad = point2.latitude * (pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  List<Map<String, dynamic>> get _sortedNearbyParks {
    if (_currentLocation == null) return _nearbyParks;
    
    List<Map<String, dynamic>> sortedParks = List.from(_nearbyParks);
    sortedParks.sort((a, b) {
      double distanceA = _calculateDistance(
        _currentLocation!,
        LatLng(a['latitude'], a['longitude']),
      );
      double distanceB = _calculateDistance(
        _currentLocation!,
        LatLng(b['latitude'], b['longitude']),
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedParks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Parks & Places'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.pushNamed(context, '/admin');
            },
            tooltip: 'Admin Panel',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map
                Expanded(
                  flex: 2,
                  child: GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? const LatLng(40.7831, -73.9712),
                      zoom: 14,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
                
                // Parks list with live dog counts
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Nearby Parks',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            const Spacer(),
                            if (_currentLocation != null)
                              Text(
                                'Sorted by distance',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _sortedNearbyParks.length + _featuredParks.length,
                            itemBuilder: (context, index) {
                              if (index < _featuredParks.length) {
                                final park = _featuredParks[index];
                                final dogCount = _parkDogCounts[park['id']] ?? 0;
                                return _buildFeaturedParkCard(park, dogCount);
                              } else {
                                final parkIndex = index - _featuredParks.length;
                                final park = _sortedNearbyParks[parkIndex];
                                final dogCount = _parkDogCounts[park['id']] ?? 0;
                                return _buildParkCard(park, dogCount);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildParkCard(Map<String, dynamic> park, int dogCount) {
    double? distance;
    if (_currentLocation != null) {
      distance = _calculateDistance(
        _currentLocation!,
        LatLng(park['latitude'], park['longitude']),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32),
          child: Text(
            dogCount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(park['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (distance != null)
              Text('${distance.toStringAsFixed(1)} km away'),
            Text(
              dogCount == 0
                  ? 'No dogs currently here'
                  : '$dogCount ${dogCount == 1 ? 'dog is' : 'dogs are'} here now',
              style: TextStyle(
                color: dogCount > 0 
                    ? const Color(0xFF2E7D32)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: dogCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showParkDetails(park, dogCount, false),
        ),
        onTap: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(park['latitude'], park['longitude']),
              16,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedParkCard(Map<String, dynamic> park, int dogCount) {
    double? distance;
    if (_currentLocation != null) {
      distance = _calculateDistance(
        _currentLocation!,
        LatLng(park['latitude'], park['longitude']),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF2E7D32).withOpacity(0.1),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF2E7D32),
              child: Text(
                dogCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Positioned(
              top: -2,
              right: -2,
              child: Icon(
                Icons.star,
                color: Colors.orange,
                size: 16,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            const Icon(Icons.star, color: Colors.orange, size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text(park['name'])),
            if (park['rating'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  park['rating'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Featured Park',
              style: TextStyle(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (distance != null)
              Text('${distance.toStringAsFixed(1)} km away'),
            Text(
              dogCount == 0
                  ? 'No dogs currently here'
                  : '$dogCount ${dogCount == 1 ? 'dog is' : 'dogs are'} here now',
              style: TextStyle(
                color: dogCount > 0 
                    ? const Color(0xFF2E7D32)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: dogCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showParkDetails(park, dogCount, true),
        ),
        onTap: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(park['latitude'], park['longitude']),
              16,
            ),
          );
        },
      ),
    );
  }

  void _showParkDetails(Map<String, dynamic> park, int dogCount, bool isFeatured) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isFeatured) ...[
                    const Icon(Icons.star, color: Colors.orange),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      park['name'],
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isFeatured && park['rating'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${park['rating']} ⭐',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Featured Park',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Live dog count
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dogCount > 0 
                      ? const Color(0xFF2E7D32).withOpacity(0.2)
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pets, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Text(
                      dogCount == 0
                          ? 'No dogs currently at this park'
                          : '$dogCount ${dogCount == 1 ? 'dog is' : 'dogs are'} here right now!',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              if (park['description'] != null) ...[
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(park['description']),
                const SizedBox(height: 16),
              ],
              
              if (isFeatured && park['amenities'] != null) ...[
                Text(
                  'Amenities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (park['amenities'] as List).map<Widget>((amenity) {
                    return Chip(
                      label: Text(amenity.toString().replaceAll('_', ' ')),
                      backgroundColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              
              // Check-in button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _checkInToPark(park),
                  icon: const Icon(Icons.location_on),
                  label: Text('Check In at ${park['name']}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkInToPark(Map<String, dynamic> park) async {
    try {
      await BarkDateUserService.checkInToPark(park['id']);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked in to ${park['name']}!'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking in: $e')),
        );
      }
    }
  }
}
