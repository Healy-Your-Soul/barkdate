import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/location_service.dart';
import 'package:barkdate/screens/map_v2/map_tab_screen.dart'; // Reuse providers if possible or create new ones
import 'package:barkdate/utils/dog_marker_generator.dart';
import 'package:barkdate/features/playdates/presentation/widgets/selection_place_sheet.dart';
import 'dart:async';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation; // Pre-fetched location from parent screen
  
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(-33.8688, 151.2093); // Sydney default
  bool _isLoading = true;
  bool _locationReady = false; // Track if we've centered on user location
  Set<Marker> _markers = {};
  
  // Custom Popup State
  PlaceResult? _selectedPlace;
  
  // Filter State
  String _selectedCategory = 'park'; // Default to parks
  bool _showOpenNow = false;

  // Track if we need to animate to user location after map creates
  LatLng? _pendingCameraTarget;
  
  // Search autocomplete state
  final TextEditingController _searchController = TextEditingController();
  List<PlaceAutocomplete> _suggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  @override
  void initState() {
    super.initState();
    
    // Use pre-fetched location if available, otherwise fetch now
    if (widget.initialLocation != null) {
      _initialPosition = widget.initialLocation!;
      _locationReady = true;
      _isLoading = false;
      // Load places immediately
      _searchNearbyPlaces(_initialPosition);
    } else {
      _getCurrentLocation();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        final userLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _initialPosition = userLocation;
          _isLoading = false;
        });
        
        // If map controller exists, animate now. Otherwise, save for later.
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(userLocation, 14),
          );
        } else {
          _pendingCameraTarget = userLocation;
        }
        
        // Load places around user
        _searchNearbyPlaces(userLocation);
      } else {
         if (mounted) {
           setState(() => _isLoading = false);
           _searchNearbyPlaces(_initialPosition);
         }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _searchNearbyPlaces(_initialPosition);
      }
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    // If we fetched location before map was ready, animate now
    if (_pendingCameraTarget != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pendingCameraTarget!, 14),
      );
      _pendingCameraTarget = null;
      // Mark location as ready after a short delay for animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _locationReady = true);
      });
    } else {
      // Location already set in _initialPosition, mark ready
      setState(() => _locationReady = true);
    }
  }

  Future<void> _searchNearbyPlaces(LatLng center) async {
    try {
      final places = await PlacesService.searchDogFriendlyPlaces(
        latitude: center.latitude, 
        longitude: center.longitude,
        radius: 2000,
        primaryTypes: ['park', 'dog_park', 'cafe'], // Prioritize relevant places
      );

      if (mounted) {
        // Filter places based on selected category
        final filteredPlaces = switch(_selectedCategory) {
          'all' => places.places,
          _ => places.places.where((p) => p.category.name.toLowerCase() == _selectedCategory || 
                                           p.category.name.toLowerCase().contains(_selectedCategory)).toList(),
        };

        // Generate custom markers
        final newMarkers = <Marker>{};
        for (final place in filteredPlaces) {
          // Open Now filter
          if (_showOpenNow && !place.isOpen) continue;

          final icon = await DogMarkerGenerator.createPlaceMarker(
            category: place.category.name,
            size: 40,
          );

          newMarkers.add(Marker(
            markerId: MarkerId(place.placeId),
            position: LatLng(place.latitude, place.longitude),
            icon: icon,
            onTap: () {
              setState(() => _selectedPlace = place);
            },
          ));
        }

        setState(() {
          _markers = newMarkers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
    }
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;
    final region = await _mapController!.getVisibleRegion();
    final center = LatLng(
      (region.northeast.latitude + region.southwest.latitude) / 2,
      (region.northeast.longitude + region.southwest.longitude) / 2,
    );
    _searchNearbyPlaces(center);
  }

  void _selectPlace(PlaceResult place) {
    Navigator.of(context).pop(place);
  }
  
  /// Handle search text changes - fetch autocomplete suggestions
  Future<void> _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final predictions = await PlacesService.autocomplete(query);
      if (mounted) {
        setState(() {
          _suggestions = predictions;
          _showSuggestions = predictions.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }
  
  /// Handle tapping a suggestion - get details and navigate camera
  Future<void> _onSuggestionTap(PlaceAutocomplete suggestion) async {
    setState(() {
      _showSuggestions = false;
      _isLoading = true;
    });
    FocusScope.of(context).unfocus();
    _searchController.text = suggestion.structuredFormatting.mainText;
    
    try {
      // Get place details to get coordinates
      final details = await PlacesService.getPlaceDetailsByPlaceId(suggestion.placeId);
      if (details != null && mounted) {
        final geometry = details['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        
        if (lat != null && lng != null) {
          final latLng = LatLng(lat, lng);
          
          // Move camera to the selected place
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 15),
          );
          
          // Update initial position and search for places there
          _initialPosition = latLng;
          _searchNearbyPlaces(latLng);
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFilterChip(String label, String value, bool selected, IconData? icon, Color? iconColor) {
    return ChoiceChip(
      avatar: icon != null 
          ? Icon(icon, size: 16, color: selected ? iconColor : Colors.grey)
          : null,
      label: Text(label),
      selected: selected,
      onSelected: (_) {
         setState(() {
           _selectedCategory = value;
           _isLoading = true;
         });
         _searchNearbyPlaces(_initialPosition);
      },
      selectedColor: iconColor?.withOpacity(0.2) ?? Theme.of(context).colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? (iconColor ?? Theme.of(context).colorScheme.primary) : Colors.grey[700],
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            onMapCreated: _onMapCreated,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (_) => setState(() => _selectedPlace = null),
            onCameraIdle: _onCameraIdle,
          ),
          
          // Search Bar & Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Search places...',
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _isSearching 
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                        )
                                      : (_searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.close, size: 20),
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _suggestions = [];
                                                  _showSuggestions = false;
                                                });
                                              },
                                            )
                                          : null),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onTap: () {
                                  if (_suggestions.isNotEmpty) {
                                    setState(() => _showSuggestions = true);
                                  }
                                },
                              ),
                            ),
                            // Suggestions dropdown
                            if (_showSuggestions && _suggestions.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _suggestions.length,
                                  itemBuilder: (context, index) {
                                    final suggestion = _suggestions[index];
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(Icons.location_on_outlined, color: Colors.grey.shade600, size: 20),
                                      title: Text(
                                        suggestion.structuredFormatting.mainText,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        suggestion.structuredFormatting.secondaryText,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _onSuggestionTap(suggestion),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12), // Gap between search and filters
                  
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Parks', 'park', _selectedCategory == 'park', Icons.park, Colors.green),
                        const SizedBox(width: 8),
                        _buildFilterChip('Cafes', 'cafe', _selectedCategory == 'cafe', Icons.local_cafe, Colors.orange),
                        const SizedBox(width: 8),
                        _buildFilterChip('Restaurants', 'restaurant', _selectedCategory == 'restaurant', Icons.restaurant, Colors.red),
                        const SizedBox(width: 8),
                         FilterChip(
                          label: const Text('Open Now'),
                          selected: _showOpenNow,
                          onSelected: (val) {
                            setState(() { 
                              _showOpenNow = val;
                              _isLoading = true;
                            });
                             _searchNearbyPlaces(_initialPosition);
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Colors.green.shade100,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Indicator / Overlay (hides Sydney flash)
          if (_isLoading || !_locationReady)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Finding your location...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            
          // My Location Button
          Positioned(
            right: 16,
            bottom: _selectedPlace != null ? 320 : 32, // Adjust based on sheet height
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          
          // Selection Sheet
          if (_selectedPlace != null)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return SelectionPlaceSheet(
                  place: _selectedPlace!,
                  scrollController: scrollController,
                  onClose: () => setState(() => _selectedPlace = null),
                  onSelect: () => _selectPlace(_selectedPlace!),
                );
              },
            ),
        ],
      ),
      ), // Close GestureDetector
    );
  }
}
