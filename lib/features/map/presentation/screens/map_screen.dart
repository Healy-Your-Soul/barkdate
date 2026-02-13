import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barkdate/features/map/presentation/providers/map_provider.dart';
import 'package:barkdate/features/map/presentation/widgets/map_search_bar.dart';
import 'package:barkdate/features/map/presentation/widgets/map_filter_chips.dart';
import 'package:barkdate/features/map/presentation/widgets/map_bottom_sheets.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/checkin_button.dart';
import 'package:barkdate/widgets/live_location_toggle.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  bool _isLoadingLocation = true;
  String? _locationError;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
        _locationError = null;
      });

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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update viewport provider
      final location = LatLng(position.latitude, position.longitude);
      ref.read(mapViewportProvider.notifier).state = ref.read(mapViewportProvider).copyWith(
        center: location,
        zoom: 14.0,
      );

      setState(() {
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = e.toString();
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;

    final bounds = await _mapController!.getVisibleRegion();
    final position = await _mapController!.getVisibleRegion(); // Wait, getVisibleRegion returns LatLngBounds
    // We need camera position for center/zoom, but getVisibleRegion gives bounds.
    // We can't get CameraPosition directly from controller easily without tracking it or using getCameraPosition (if available, mostly not in controller).
    // Actually we can track it in onCameraMove.
    
    // But better: just update bounds in provider, which triggers fetch.
    // We also need center for search radius.
    
    // Let's assume we tracked center in onCameraMove but didn't update provider to avoid rebuilds.
    // Or we can just use the bounds center.
    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    
    ref.read(mapViewportProvider.notifier).state = ref.read(mapViewportProvider).copyWith(
      center: LatLng(centerLat, centerLng),
      bounds: bounds,
    );
  }

  Future<void> _recenterMap() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final location = LatLng(position.latitude, position.longitude);
      
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(location, 14.0),
        );
      }
      
      // Provider update will happen in _onCameraIdle
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  void _updateMarkers(MapData data) {
    final filters = ref.read(mapFiltersProvider);
    final newMarkers = <Marker>{};

    // Places
    for (final place in data.places) {
       // Filter by category if needed (though repository might have done it, or we do it here)
       if (filters.category != 'all' && place.category.name != filters.category) {
         // Simple string check, might need better mapping
         // Actually PlaceCategory is an enum.
         // Let's map filter string to enum or check display name
         if (place.category.name.toLowerCase() != filters.category && 
             place.category.displayName.toLowerCase() != filters.category) {
            // This is a bit loose, but okay for now.
            // Better: 'park' -> PlaceCategory.park
            if (filters.category == 'park' && place.category != PlaceCategory.park) continue;
            if (filters.category == 'cafe' && place.category != PlaceCategory.restaurant) continue; // Assuming cafe is restaurant
            if (filters.category == 'store' && place.category != PlaceCategory.petStore) continue;
         }
       }

       if (filters.openNow && !place.isOpen) continue;

       final dogCount = data.checkInCounts[place.placeId] ?? 0;
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

    // Events
    if (filters.showEvents) {
      for (final event in data.events) {
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

    // We should only update state if markers changed to avoid loops?
    // Actually build() is called when provider changes, so we can just calculate markers here.
    // But we can't call setState in build.
    // So we should calculate markers in build and pass to GoogleMap.
    _markers = newMarkers;
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

  @override
  Widget build(BuildContext context) {
    final viewport = ref.watch(mapViewportProvider);
    final selection = ref.watch(mapSelectionProvider);
    final mapDataAsync = ref.watch(mapDataProvider);

    // Update markers when data is available
    mapDataAsync.whenData((data) {
      _updateMarkers(data);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dog Friendly Map'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator())
          else if (_locationError != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Location unavailable', style: Theme.of(context).textTheme.titleLarge),
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
          if (!mapDataAsync.isLoading && !selection.hasSelection)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.refresh(mapDataProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Search this area'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4CAF50),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),

          // Loading indicator
          if (mapDataAsync.isLoading)
             Positioned(
               top: 50,
               left: 0,
               right: 0,
               child: Center(
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(20),
                     boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
                   ),
                   child: const Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                       SizedBox(width: 8),
                       Text('Searching area...'),
                     ],
                   ),
                 ),
               ),
             ),

          // Bottom UI
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: !selection.hasSelection
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const MapSearchBar(),
                      ),
                      const SizedBox(height: 16),
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const MapFilterChips(),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedAiButton(
                                onPressed: () {
                                  ref.read(mapSelectionProvider.notifier).showAiAssistant();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Recenter button - positioned at top-right of map area
          Positioned(
            right: 16,
            top: 8,
            child: FloatingActionButton.small(
              heroTag: 'recenter_btn',
              onPressed: _recenterMap,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(
                Icons.my_location,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),

          // Live Location Toggle (Phase 5)
          Positioned(
            right: 16,
            top: 60,
            child: const LiveLocationToggle(),
          ),

          // Floating check-in status indicator
          Positioned(
            left: 16,
            top: 8,
            child: FloatingCheckInIndicator(
              onTap: (placeId, placeName) {
                // Find the place and select it
                final places = mapDataAsync.value?.places ?? [];
                final place = places.where((p) => p.placeId == placeId).firstOrNull;
                if (place != null) {
                  ref.read(mapSelectionProvider.notifier).selectPlace(place);
                }
              },
            ),
          ),

          // Bottom sheets
          if (selection.hasSelection)
            Positioned.fill(
              child: MapBottomSheets(
                places: mapDataAsync.value?.places ?? [],
                events: mapDataAsync.value?.events ?? [],
                checkInCounts: mapDataAsync.value?.checkInCounts ?? {},
                onCheckInSuccess: () {
                  ref.refresh(mapDataProvider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated AI button with gradient and glow effect
class AnimatedAiButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedAiButton({super.key, required this.onPressed});

  @override
  State<AnimatedAiButton> createState() => _AnimatedAiButtonState();
}

class _AnimatedAiButtonState extends State<AnimatedAiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF6366F1), // Indigo
                Color(0xFF8B5CF6), // Purple
                Color(0xFF06B6D4), // Cyan
              ],
              stops: [
                0.0,
                0.5 + (_shimmerAnimation.value * 0.3),
                1.0,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AI Map Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating indicator showing current check-in status
class FloatingCheckInIndicator extends StatefulWidget {
  final Function(String placeId, String placeName)? onTap;

  const FloatingCheckInIndicator({super.key, this.onTap});

  @override
  State<FloatingCheckInIndicator> createState() => _FloatingCheckInIndicatorState();
}

class _FloatingCheckInIndicatorState extends State<FloatingCheckInIndicator> {
  String? _checkedInPlaceId;
  String? _checkedInPlaceName;

  @override
  void initState() {
    super.initState();
    _loadCheckInStatus();
  }

  Future<void> _loadCheckInStatus() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted) {
        setState(() {
          _checkedInPlaceId = checkIn?.parkId;
          _checkedInPlaceName = checkIn?.parkName;
        });
      }
    } catch (e) {
      debugPrint('Error loading check-in status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkedInPlaceId == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (_checkedInPlaceId != null && _checkedInPlaceName != null) {
            widget.onTap?.call(_checkedInPlaceId!, _checkedInPlaceName!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.pets, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: Text(
                  _checkedInPlaceName ?? 'Checked In',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
