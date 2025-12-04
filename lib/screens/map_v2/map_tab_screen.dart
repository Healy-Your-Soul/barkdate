import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:barkdate/screens/map_v2/providers/map_viewport_provider.dart';
import 'package:barkdate/screens/map_v2/providers/map_filters_provider.dart';
import 'package:barkdate/screens/map_v2/providers/map_selection_provider.dart';
import 'package:barkdate/screens/map_v2/widgets/map_search_bar.dart';
import 'package:barkdate/screens/map_v2/widgets/map_filter_chips.dart';
import 'package:barkdate/screens/map_v2/widgets/map_bottom_sheets.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/events_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/models/event.dart';

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

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    
    // Auto-refresh check-ins every 30 seconds
    _checkInRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshCheckInCounts(),
    );
  }

  @override
  void dispose() {
    _checkInRefreshTimer?.cancel();
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

    if (bbox == null || _userPosition == null) return;

    setState(() => _isLoadingPlaces = true);

    try {
      // Fetch places with larger radius (50km to ensure we get results)
      final placesResult = await PlacesService.searchDogFriendlyPlaces(
        latitude: _userPosition!.latitude,
        longitude: _userPosition!.longitude,
        radius: 50000, // 50km radius to ensure we get results
        keyword: filters.searchQuery.isEmpty ? null : filters.searchQuery,
      );

      // Fetch events if enabled
      List<Event> events = [];
      if (filters.showEvents) {
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

  void _updateMarkers() {
    final filters = ref.read(mapFiltersProvider);
    final newMarkers = <Marker>{};

    // Add place markers
    for (final place in _places) {
      // Apply filters
      if (filters.searchQuery.isNotEmpty &&
          !place.name.toLowerCase().contains(filters.searchQuery.toLowerCase())) {
        continue;
      }

      if (filters.openNow && !place.isOpen) {
        continue;
      }

      // Get check-in count for this place
      final dogCount = _checkInCounts[place.placeId] ?? 0;
      final snippet = dogCount > 0
          ? '$dogCount 🐕 here now • ${place.distanceText}'
          : '${place.category.icon} ${place.distanceText}';

      newMarkers.add(Marker(
        markerId: MarkerId('place_${place.placeId}'),
        position: LatLng(place.latitude, place.longitude),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: snippet,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerColor(place.category),
        ),
        onTap: () {
          ref.read(mapSelectionProvider.notifier).selectPlace(place);
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

    setState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    ref.read(mapViewportProvider.notifier).attachMapController(controller);
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    ref.read(mapViewportProvider.notifier).updateBounds(bounds);

    // Refetch when camera stops moving
    _fetchPlacesAndEvents();
  }

  void _onCameraMove(CameraPosition position) {
    ref.read(mapViewportProvider.notifier).updateCamera(
      position.target,
      position.zoom,
    );
    ref.read(mapViewportProvider.notifier).setMoving(true);
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
            ),

          // Search This Area button
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _fetchPlacesAndEvents,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search This Area',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLoadingPlaces) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom UI Section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: !selection.hasSelection
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const MapSearchBar(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Filters panel
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const MapFilterChips(),
                            const SizedBox(height: 16),
                            
                            // AI Assistant button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(mapSelectionProvider.notifier).showAiAssistant();
                                },
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('AI Map Assistant'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Recenter button
          Positioned(
            right: 16,
            bottom: selection.hasSelection ? 320 : 280,
            child: FloatingActionButton.small(
              onPressed: _recenterMap,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 4,
              child: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),

      // Bottom sheets
      bottomSheet: selection.hasSelection
          ? MapBottomSheets(
              places: _places,
              events: _events,
              checkInCounts: _checkInCounts,
              onCheckInSuccess: _refreshCheckInCounts,
            )
          : null,
    );
  }
}
