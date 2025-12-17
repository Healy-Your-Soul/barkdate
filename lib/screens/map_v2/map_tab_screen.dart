import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/screens/map_v2/providers/map_viewport_provider.dart';
import 'package:barkdate/screens/map_v2/providers/map_filters_provider.dart';
import 'package:barkdate/screens/map_v2/providers/map_selection_provider.dart';
import 'package:barkdate/screens/map_v2/widgets/map_search_bar.dart';
import 'package:barkdate/screens/map_v2/widgets/map_filter_chips.dart';
import 'package:barkdate/screens/map_v2/widgets/map_bottom_sheets.dart';
import 'package:barkdate/screens/map_v2/widgets/simple_place_sheet.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/events_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/services/location_service.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/models/checkin.dart';
import 'package:barkdate/widgets/live_location_toggle.dart';
import 'package:barkdate/utils/dog_marker_generator.dart';
import 'package:barkdate/screens/map_v2/widgets/dog_mini_card.dart';
import 'package:barkdate/screens/map_v2/widgets/place_mini_card.dart';

/// New map tab with AI assistant, event integration, and improved UX
class MapTabScreenV2 extends ConsumerStatefulWidget {
  const MapTabScreenV2({super.key});

  @override
  ConsumerState<MapTabScreenV2> createState() => _MapTabScreenV2State();
}

class _MapTabScreenV2State extends ConsumerState<MapTabScreenV2> {
  GoogleMapController? _mapController;
  Position? _userPosition;
  bool _isLoadingLocation = true;
  String? _locationError;

  final Set<Marker> _markers = {};
  final List<PlaceResult> _places = [];
  final List<Event> _events = [];
  final Map<String, int> _checkInCounts = {}; // Place ID -> dog count
  bool _isLoadingPlaces = false;
  Timer? _checkInRefreshTimer;
  Timer? _liveUsersRefreshTimer;
  
  // Live users on map (Phase 5)
  final List<Map<String, dynamic>> _liveUsers = [];
  final List<Marker> _liveUserMarkers = [];
  
  // Selected place for in-stack sheet (not modal)
  PlaceResult? _selectedPlace;
  
  // Selected live dog for mini popup (Phase 5)
  Map<String, dynamic>? _selectedLiveDog;
  
  // Selected place for mini popup (tapped marker - shows compact card first)
  PlaceResult? _tappedPlaceMarker;
  
  // Current user's check-in status (for top-left floating button)
  CheckIn? _currentUserCheckIn;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadUserCheckIn(); // Load user's current check-in status
    
    // Auto-refresh check-ins every 30 seconds
    _checkInRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshCheckInCounts(),
    );
    
    // Auto-refresh live users every 30 seconds
    _liveUsersRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshLiveUsers(),
    );
  }

  @override
  void dispose() {
    _checkInRefreshTimer?.cancel();
    _liveUsersRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
        _locationError = null;
      });

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userPosition = position;
        _isLoadingLocation = false;
      });

      // Update viewport
      final location = LatLng(position.latitude, position.longitude);
      ref.read(mapViewportProvider.notifier).updateCamera(location, 14.0);

      // Fetch initial data
      _fetchPlacesAndEvents();
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = e.toString();
      });
      debugPrint('❌ Location error: $e');
    }
  }

  Future<void> _fetchPlacesAndEvents() async {
    final viewport = ref.read(mapViewportProvider);
    final filters = ref.read(mapFiltersProvider);
    final bbox = viewport.boundingBox;

    // Use map center from viewport for search (where user panned to)
    // Fall back to user position only if viewport center is not available
    final searchCenter = viewport.center;
    
    if (searchCenter.latitude == 0 && searchCenter.longitude == 0 && _userPosition == null) {
      debugPrint('⚠️ _fetchPlacesAndEvents: skipping - no search center available');
      return;
    }

    // Determine search coordinates - prefer viewport center (where user panned)
    final searchLat = searchCenter.latitude != 0 ? searchCenter.latitude : _userPosition!.latitude;
    final searchLng = searchCenter.longitude != 0 ? searchCenter.longitude : _userPosition!.longitude;

    setState(() => _isLoadingPlaces = true);

    try {
      // Get primary types based on selected category
      final primaryTypes = filters.primaryTypes;
      debugPrint('🔍 Fetching places with types: $primaryTypes');
      debugPrint('📍 Search center (map viewport): lat=$searchLat, lng=$searchLng');
      
      // Fetch places within 5km radius of MAP CENTER (not user position!)
      final placesResult = await PlacesService.searchDogFriendlyPlaces(
        latitude: searchLat,
        longitude: searchLng,
        radius: 5000, // 5km radius for relevant nearby results
        keyword: filters.searchQuery.isEmpty ? null : filters.searchQuery,
        primaryTypes: primaryTypes,
      );

      // Fetch events if enabled AND we have a valid bounding box
      List<Event> events = [];
      if (filters.showEvents && bbox != null) {
        final eventsService = EventsService();
        events = await eventsService.fetchEventsInViewport(
          south: bbox.south,
          west: bbox.west,
          north: bbox.north,
          east: bbox.east,
        );
      }

      setState(() {
        _places.clear();
        _places.addAll(placesResult.places);
        _events.clear();
        _events.addAll(events);
        _isLoadingPlaces = false;
      });

      // Fetch check-in counts for the places
      await _refreshCheckInCounts();
      
      // Fetch live users nearby
      await _refreshLiveUsers();
      
      _updateMarkers();
    } catch (e) {
      debugPrint('❌ Error fetching data: $e');
      setState(() => _isLoadingPlaces = false);
    }
  }

  Future<void> _refreshCheckInCounts() async {
    if (_places.isEmpty) return;

    try {
      final placeIds = _places.map((p) => p.placeId).toList();
      final counts = await CheckInService.getPlaceDogCounts(placeIds);
      
      if (mounted) {
        setState(() {
          _checkInCounts.clear();
          _checkInCounts.addAll(counts);
        });
        _updateMarkers(); // Rebuild markers with new counts
      }
    } catch (e) {
      debugPrint('❌ Error refreshing check-in counts: $e');
    }
  }

  /// Refresh live users on the map (Phase 5)
  Future<void> _refreshLiveUsers() async {
    if (_userPosition == null) return;
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      final liveUsers = await LocationService.getNearbyLiveUsers(
        userId,
        _userPosition!.latitude,
        _userPosition!.longitude,
        radiusKm: 10.0,
      );
      
      debugPrint('📍 Live users found: ${liveUsers.length}');
      
      // DEBUG: If no other live users, show our own marker so we can see the feature
      if (liveUsers.isEmpty) {
        debugPrint('🔧 DEBUG: No live users nearby, adding self marker for testing');
        // Get current user's dog info and user name
        final userDogs = await Supabase.instance.client
            .from('dogs')
            .select('name, main_photo_url')
            .eq('user_id', userId)
            .limit(1);
        
        // Get user name
        final userData = await Supabase.instance.client
            .from('users')
            .select('name')
            .eq('id', userId)
            .single();
        
        if (userDogs.isNotEmpty) {
          liveUsers.add({
            'user_id': userId,
            'user_name': userData['name'] ?? 'You',
            'dog_name': userDogs[0]['name'],
            'dog_photo_url': userDogs[0]['main_photo_url'],
            'live_latitude': _userPosition!.latitude,
            'live_longitude': _userPosition!.longitude,
            'live_location_updated_at': DateTime.now().toIso8601String(),
            'is_friend': false,
            'distance_km': 0.0,
          });
          debugPrint('🐕 Added debug marker: ${userDogs[0]['name']}');
        }
      }
      
      if (mounted) {
        setState(() {
          _liveUsers.clear();
          _liveUsers.addAll(liveUsers);
        });
        await _updateLiveUserMarkers();
        _updateMarkers();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing live users: $e');
    }
  }

  /// Generate custom markers for live users with dog photos and colored borders
  Future<void> _updateLiveUserMarkers() async {
    final newMarkers = <Marker>[];
    
    for (final liveUser in _liveUsers) {
      final latitude = liveUser['live_latitude'] as double?;
      final longitude = liveUser['live_longitude'] as double?;
      final dogName = liveUser['dog_name'] as String? ?? liveUser['user_name'] as String? ?? 'Unknown';
      final dogPhotoUrl = liveUser['dog_photo_url'] as String? ?? liveUser['avatar_url'] as String?;
      final isFriend = liveUser['is_friend'] as bool? ?? false;
      final updatedAt = liveUser['live_location_updated_at'] as String?;
      
      if (latitude == null || longitude == null) continue;
      
      // Calculate hours since update
      double hoursAgo = 0;
      if (updatedAt != null) {
        final updateTime = DateTime.tryParse(updatedAt);
        if (updateTime != null) {
          hoursAgo = DateTime.now().difference(updateTime).inMinutes / 60.0;
        }
      }
      
      // Get border color based on freshness
      final borderColor = DogMarkerGenerator.getBorderColorForAge(hoursAgo);
      
      // Generate custom marker with dog photo and colored border (42px size)
      final icon = await DogMarkerGenerator.createDogMarker(
        imageUrl: dogPhotoUrl,
        borderColor: borderColor,
        size: 42,
        borderWidth: 3,
      );
      
      newMarkers.add(Marker(
        markerId: MarkerId('live_${liveUser['user_id']}'),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow.noText, // Disable default info window
        icon: icon,
        onTap: () {
          // Show dog mini card popup
          setState(() => _selectedLiveDog = liveUser);
        },
      ));
    }
    
    if (mounted) {
      setState(() {
        _liveUserMarkers.clear();
        _liveUserMarkers.addAll(newMarkers);
      });
    }
  }

  Future<void> _updateMarkers() async {
    final filters = ref.read(mapFiltersProvider);
    final newMarkers = <Marker>{};
    
    debugPrint('🗺️ _updateMarkers called: ${_places.length} places, ${_liveUserMarkers.length} live users');

    // Add place markers
    for (final place in _places) {
      // Apply search query filter
      if (filters.searchQuery.isNotEmpty &&
          !place.name.toLowerCase().contains(filters.searchQuery.toLowerCase())) {
        continue;
      }

      // Apply open now filter
      if (filters.openNow && !place.isOpen) {
        continue;
      }
      
      // Note: Category filtering is now done at the Google API level (primaryTypes)
      // so no client-side category filtering needed here

      // Get check-in count for this place
      final dogCount = _checkInCounts[place.placeId] ?? 0;

      // Generate custom marker based on category
      final categoryName = place.category.name;
      final icon = await DogMarkerGenerator.createPlaceMarker(
        category: categoryName,
        size: 40,
      );

      newMarkers.add(Marker(
        markerId: MarkerId('place_${place.placeId}'),
        position: LatLng(place.latitude, place.longitude),
        infoWindow: InfoWindow.noText,
        icon: icon,
        onTap: () {
          // Open place sheet directly
          setState(() => _selectedPlace = place);
        },
      ));
    }

    // Add event markers if enabled
    if (filters.showEvents) {
      for (final event in _events) {
        if (event.latitude == null || event.longitude == null) continue;

        newMarkers.add(Marker(
          markerId: MarkerId('event_${event.id}'),
          position: LatLng(event.latitude!, event.longitude!),
          infoWindow: InfoWindow(
            title: event.title,
            snippet: '${event.categoryIcon} ${event.formattedDate}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          onTap: () {
            ref.read(mapSelectionProvider.notifier).selectEvent(event);
          },
        ));
      }
    }

    // Add live user markers (Phase 5) - dog photos with colored borders
    for (final marker in _liveUserMarkers) {
      newMarkers.add(marker);
    }

    // Add checked-in user marker (special paw icon at check-in location)
    if (_currentUserCheckIn != null && 
        _currentUserCheckIn!.latitude != null && 
        _currentUserCheckIn!.longitude != null) {
      final checkedInAt = _currentUserCheckIn!.checkedInAt;
      final hoursAgo = DateTime.now().difference(checkedInAt).inMinutes / 60.0;
      
      // Only show if within 4 hours
      if (hoursAgo < 4) {
        final borderColor = hoursAgo < 1 ? Colors.green 
            : hoursAgo < 2 ? Colors.orange 
            : Colors.red;
        
        newMarkers.add(Marker(
          markerId: const MarkerId('my_checkin'),
          position: LatLng(
            _currentUserCheckIn!.latitude!,
            _currentUserCheckIn!.longitude!,
          ),
          infoWindow: InfoWindow(
            title: '🐕 You\'re here!',
            snippet: _currentUserCheckIn!.parkName,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            hoursAgo < 1 ? BitmapDescriptor.hueGreen 
                : hoursAgo < 2 ? BitmapDescriptor.hueOrange 
                : BitmapDescriptor.hueRed,
          ),
          zIndex: 10, // Show on top
        ));
      }
    }

    debugPrint('🗺️ Setting ${newMarkers.length} markers on map');
    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
  }

  /// Get marker hue based on how recently the user updated their location
  double _getLiveUserMarkerHue(double hoursAgo) {
    if (hoursAgo < 1.0) {
      return BitmapDescriptor.hueGreen; // 0-1 hour: green
    } else if (hoursAgo < 3.0) {
      return BitmapDescriptor.hueOrange; // 1-3 hours: orange
    } else {
      return BitmapDescriptor.hueRed; // 3-4 hours: red (will expire soon)
    }
  }

  /// Format time ago for display
  String _formatTimeAgo(double hoursAgo) {
    if (hoursAgo < 1.0 / 60.0) {
      return 'Just now';
    } else if (hoursAgo < 1.0) {
      final minutes = (hoursAgo * 60).round();
      return '${minutes}m ago';
    } else {
      final hours = hoursAgo.round();
      return '${hours}h ago';
    }
  }
  
  /// Calculate hours since location update
  double _calculateHoursAgo(String? updatedAt) {
    if (updatedAt == null) return 0;
    final updateTime = DateTime.tryParse(updatedAt);
    if (updateTime == null) return 0;
    return DateTime.now().difference(updateTime).inMinutes / 60.0;
  }

  double _getMarkerColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.park:
        return BitmapDescriptor.hueGreen;
      case PlaceCategory.petStore:
        return BitmapDescriptor.hueOrange;
      case PlaceCategory.veterinary:
        return BitmapDescriptor.hueRed;
      case PlaceCategory.restaurant:
        return BitmapDescriptor.hueBlue;
      default:
        return BitmapDescriptor.hueRose;
    }
  }
  
  /// Load current user's check-in status
  Future<void> _loadUserCheckIn() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('📍 Check-in: No user logged in');
      return;
    }
    
    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      debugPrint('📍 Check-in loaded: ${checkIn?.parkName ?? "None"}');
      if (mounted) {
        setState(() => _currentUserCheckIn = checkIn);
        _updateMarkers(); // Refresh markers to show/hide check-in marker
      }
    } catch (e) {
      debugPrint('Error loading user check-in: $e');
    }
  }
  
  /// Build collapsed filter chips (just category buttons)
  Widget _buildCollapsedFilterChips() {
    final filters = ref.watch(mapFiltersProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all', filters.category == 'all', null, null),
          const SizedBox(width: 8),
          _buildFilterChip('Parks', 'park', filters.category == 'park', Icons.park, Colors.green),
          const SizedBox(width: 8),
          _buildFilterChip('Cafes', 'cafe', filters.category == 'cafe', Icons.local_cafe, Colors.orange),
          const SizedBox(width: 8),
          _buildFilterChip('Stores', 'store', filters.category == 'store', Icons.store, Colors.blue),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value, bool selected, IconData? icon, Color? iconColor) {
    return ChoiceChip(
      avatar: icon != null 
          ? Icon(icon, size: 16, color: selected ? iconColor : Colors.grey)
          : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        ref.read(mapFiltersProvider.notifier).setCategory(value);
      },
      selectedColor: iconColor?.withOpacity(0.2) ?? Theme.of(context).colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? (iconColor ?? Theme.of(context).colorScheme.primary) : Colors.grey[700],
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  /// Build check-in status floating button (top-left)
  Widget _buildCheckInStatusButton() {
    if (_currentUserCheckIn == null) return const SizedBox.shrink();
    
    // Calculate color based on check-in freshness
    final checkedInAt = _currentUserCheckIn!.checkedInAt;
    final hoursAgo = DateTime.now().difference(checkedInAt).inMinutes / 60.0;
    
    // Auto-hide after 4 hours
    if (hoursAgo >= 4) {
      // Schedule clearing the check-in state
      Future.microtask(() {
        if (mounted) setState(() => _currentUserCheckIn = null);
      });
      return const SizedBox.shrink();
    }
    
    // Color based on freshness
    Color statusColor;
    if (hoursAgo < 1) {
      statusColor = Colors.green;
    } else if (hoursAgo < 2) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }
    
    return GestureDetector(
      onTap: () => _openCheckedInPlace(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: statusColor, size: 18),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                _currentUserCheckIn!.parkName,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Open the place sheet for the checked-in location
  void _openCheckedInPlace() {
    if (_currentUserCheckIn == null) return;
    
    // Find the place in our list or create a minimal PlaceResult
    final matchingPlace = _places.where(
      (p) => p.placeId == _currentUserCheckIn!.parkId
    ).firstOrNull;
    
    if (matchingPlace != null) {
      setState(() => _selectedPlace = matchingPlace);
    } else {
      // Create a minimal PlaceResult for the checked-in location
      final minimalPlace = PlaceResult(
        placeId: _currentUserCheckIn!.parkId,
        name: _currentUserCheckIn!.parkName,
        address: '',
        latitude: _currentUserCheckIn!.latitude ?? 0,
        longitude: _currentUserCheckIn!.longitude ?? 0,
        rating: 0,
        userRatingsTotal: 0,
        distance: 0,
        category: PlaceCategory.other,
        isOpen: true,
      );
      setState(() => _selectedPlace = minimalPlace);
    }
  }
  
  /// Build check-in status banner for bottom panel
  Widget _buildCheckInBanner() {
    if (_currentUserCheckIn == null) return const SizedBox.shrink();
    
    final checkedInAt = _currentUserCheckIn!.checkedInAt;
    final hoursAgo = DateTime.now().difference(checkedInAt).inMinutes / 60.0;
    
    if (hoursAgo >= 4) return const SizedBox.shrink();
    
    // Color and message based on freshness
    Color statusColor;
    String message;
    
    if (hoursAgo < 1) {
      statusColor = Colors.green;
      message = "You're at ${_currentUserCheckIn!.parkName}";
    } else if (hoursAgo < 2) {
      statusColor = Colors.orange;
      message = "Still sniffing around ${_currentUserCheckIn!.parkName}? 🐕";
    } else {
      statusColor = Colors.red;
      message = "Still at ${_currentUserCheckIn!.parkName}? Really? 😄";
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _openCheckedInPlace(),
            child: Text(
              'View',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    ref.read(mapViewportProvider.notifier).attachMapController(controller);
    
    // Auto-load markers when map is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchPlacesAndEvents();
      }
    });
  }

  Timer? _debounceTimer;

  void _onCameraIdle() async {
    if (_mapController == null) return;

    // Debounce the update to prevent rapid-fire fetches and crashes
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      
      final bounds = await _mapController!.getVisibleRegion();
      ref.read(mapViewportProvider.notifier).updateBounds(bounds);

      // Refetch when camera stops moving
      _fetchPlacesAndEvents();
    });
  }

  void _onCameraMove(CameraPosition position) {
    // Note: detailed state updates during move are disabled for performance
    // ref.read(mapViewportProvider.notifier).updateCamera(position);
  }

  void _recenterMap() {
    if (_userPosition != null) {
      ref.read(mapViewportProvider.notifier).recenter(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = ref.watch(mapViewportProvider);
    final selection = ref.watch(mapSelectionProvider);
    
    // Listen for filter changes and update markers
    ref.listen(mapFiltersProvider, (previous, next) {
      if (previous?.category != next.category) {
        // Category changed - refetch from Google with new types
        _fetchPlacesAndEvents();
      } else if (previous?.openNow != next.openNow ||
          previous?.showEvents != next.showEvents) {
        // Just refresh markers for other filter changes
        _updateMarkers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Friendly Map Assistant'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else if (_locationError != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Location unavailable',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _getUserLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            GoogleMap(
            cloudMapId: '745ef4f99c0756c12303e928', // Enables Vector Map & AdvancedMarkerElement
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
              initialCameraPosition: CameraPosition(
                target: viewport.center,
                zoom: viewport.zoom,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              // CRITICAL: Allow map gestures even when sheet is visible
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              },
            ),

          // Search This Area button - transparent with black text
          Positioned(
            top: 50, // Below Live toggle and Check-in button
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _isLoadingPlaces ? null : _fetchPlacesAndEvents,
                icon: _isLoadingPlaces
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.refresh, size: 14, color: Colors.black54),
                label: Text(
                  _isLoadingPlaces ? 'Searching...' : 'Search this area',
                  style: const TextStyle(color: Colors.black87),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.85),
                  foregroundColor: Colors.black87,
                  elevation: 0, // Flat design - no shadow
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
          ),

          // Bottom: Category filter chips (always shown)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category chips only (collapsed mode)
                  _buildCollapsedFilterChips(),
                  const SizedBox(height: 8),
                  // AI Assistant button - smaller
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        ref.read(mapSelectionProvider.notifier).showAiAssistant();
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('AI Map Assistant (Arriving soon)'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Check-in status banner (below AI button)
                  if (_currentUserCheckIn != null) ...[
                    const SizedBox(height: 8),
                    _buildCheckInBanner(),
                  ],
                ],
              ),
            ),
          ),

          // Search bar + Target button (above filters, same line)
          Positioned(
            // Move higher when check-in banner is shown to avoid covering filters
            bottom: _currentUserCheckIn != null ? 150 : 110,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Search bar (expanded)
                const Expanded(child: MapSearchBar()),
                const SizedBox(width: 8),
                // Target/Recenter button (flat style matching search)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _recenterMap,
                    icon: Icon(
                      Icons.my_location,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'My Location',
                  ),
                ),
              ],
            ),
          ),

          // Live Location Toggle - TOP (above Search This Area)
          Positioned(
            right: 16,
            top: 8,
            child: LiveLocationToggle(
              onStateChanged: _refreshLiveUsers,
            ),
          ),

          // Check-in Status Button - TOP LEFT (above Search This Area)
          if (_currentUserCheckIn != null)
            Positioned(
              left: 16,
              top: 8,
              child: _buildCheckInStatusButton(),
            ),

          // Dog mini card popup when a live dog marker is tapped
          if (_selectedLiveDog != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Center(
                child: DogMiniCard(
                  dogName: _selectedLiveDog!['dog_name'] as String? ?? 
                           _selectedLiveDog!['user_name'] as String? ?? 
                           'Unknown',
                  humanName: _selectedLiveDog!['user_name'] as String?,
                  dogPhotoUrl: _selectedLiveDog!['dog_photo_url'] as String? ??
                               _selectedLiveDog!['avatar_url'] as String?,
                  timeAgo: _formatTimeAgo(_calculateHoursAgo(_selectedLiveDog!['live_location_updated_at'] as String?)),
                  isFriend: _selectedLiveDog!['is_friend'] as bool? ?? false,
                  onBark: () {
                    // TODO: Send bark to user
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🐕 You barked at ${_selectedLiveDog!['dog_name'] ?? 'this dog'}!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    setState(() => _selectedLiveDog = null);
                  },
                  onClose: () => setState(() => _selectedLiveDog = null),
                ),
              ),
            ),

          // Place mini card popup when a place marker is tapped
          if (_tappedPlaceMarker != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: Center(
                child: PlaceMiniCard(
                  place: _tappedPlaceMarker!,
                  onTap: () {
                    // Open full place sheet
                    setState(() {
                      _selectedPlace = _tappedPlaceMarker;
                      _tappedPlaceMarker = null;
                    });
                  },
                  onClose: () => setState(() => _tappedPlaceMarker = null),
                ),
              ),
            ),

          // Only show AI Assistant sheet (places use modal now)
          if (selection.showAiAssistant)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: const GeminiAssistantSheet(),
            ),

          // In-stack Place Details Sheet (NOT modal - gives us gesture control)
          if (_selectedPlace != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {}, // Catch taps
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.45,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: _buildPlaceSheetContent(
                          _selectedPlace!,
                          ScrollController(), // Pass a dummy controller or local one
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build the place sheet content using PlaceSheetContent widget
  Widget _buildPlaceSheetContent(PlaceResult place, ScrollController scrollController) {
    return PlaceSheetContent(
      place: place,
      scrollController: scrollController,
      onClose: () => setState(() => _selectedPlace = null),
      onCheckInChanged: () => _loadUserCheckIn(), // Refresh check-in state
    );
  }
}
