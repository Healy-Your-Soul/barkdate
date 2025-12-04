import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barkdate/features/map/presentation/providers/map_provider.dart';
import 'package:barkdate/features/map/presentation/widgets/map_search_bar.dart';
import 'package:barkdate/features/map/presentation/widgets/map_filter_chips.dart';
import 'package:barkdate/features/map/presentation/widgets/map_bottom_sheets.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/widgets/checkin_button.dart';

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
              top: 80,
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
                    foregroundColor: Theme.of(context).colorScheme.primary,
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
               top: 80,
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

          // Bottom sheets - as Positioned widget instead of Scaffold.bottomSheet
          if (selection.hasSelection)
          // Bottom sheets - as Positioned widget instead of Scaffold.bottomSheet
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
