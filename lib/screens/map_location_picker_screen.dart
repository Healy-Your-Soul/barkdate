import 'dart:async';

import 'package:barkdate/services/location_service.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLocationResult {
  final double latitude;
  final double longitude;
  final String? address;
  final String? placeName;

  const MapLocationResult({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
  });
}

class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLabel;

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLabel,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  String? _selectedAddress;
  String? _selectedPlaceName;
  bool _mapReady = false;
  bool _initializing = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<PlaceAutocomplete> _suggestions = [];
  bool _isSearching = false;

  static const LatLng _defaultLatLng =
      LatLng(37.7749, -122.4194); // San Francisco fallback

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    LatLng target = _defaultLatLng;
    String? label = widget.initialLabel;

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      target = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        target = LatLng(position.latitude, position.longitude);
      }
    }

    setState(() {
      _selectedLatLng = target;
      _selectedAddress = label;
      _initializing = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() => _mapReady = true);
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLatLng = position;
      _selectedAddress =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      _selectedPlaceName = null;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _performAutocomplete(value));
  }

  Future<void> _performAutocomplete(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    if (_selectedLatLng == null) {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        _selectedLatLng = LatLng(position.latitude, position.longitude);
      }
    }

    final referencePoint = _selectedLatLng ?? _defaultLatLng;

    setState(() => _isSearching = true);
    try {
      final result = await PlacesService.searchDogFriendlyPlaces(
        latitude: referencePoint.latitude,
        longitude: referencePoint.longitude,
        keyword: query,
      );

      setState(() {
        _suggestions = result.places
            .map(
              (place) => PlaceAutocomplete(
                placeId: place.placeId,
                description: place.address,
                structuredFormatting: PlaceStructuredFormatting(
                  mainText: place.name,
                  secondaryText: place.address,
                ),
              ),
            )
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location search failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _onSuggestionSelected(PlaceAutocomplete suggestion) async {
    _searchFocus.unfocus();
    _searchController.text = suggestion.structuredFormatting.mainText;
    setState(() => _suggestions = []);

    // COST OPTIMIZATION: Reset session token after selection
    PlacesSessionTokenManager.resetToken();

    try {
      final details =
          await PlacesService.getPlaceDetailsByPlaceId(suggestion.placeId);
      if (details != null) {
        final geometry = details['geometry']?['location'];
        if (geometry != null) {
          final lat = (geometry['lat'] as num).toDouble();
          final lng = (geometry['lng'] as num).toDouble();
          final address =
              details['formatted_address'] as String? ?? suggestion.description;
          final placeName = details['name'] as String? ??
              suggestion.structuredFormatting.mainText;

          final target = LatLng(lat, lng);
          setState(() {
            _selectedLatLng = target;
            _selectedAddress = address;
            _selectedPlaceName = placeName;
          });

          await _mapController
              ?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load place details: ${e.toString()}')),
        );
      }
    }
  }

  void _confirmSelection() {
    final latLng = _selectedLatLng;
    if (latLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap on the map to select a location.')),
      );
      return;
    }

    Navigator.pop(
      context,
      MapLocationResult(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        address: _selectedAddress,
        placeName: _selectedPlaceName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Event Location'),
          actions: [
            TextButton(
              onPressed: _confirmSelection,
              child: const Text('Use this place'),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_initializing)
              const Center(child: CircularProgressIndicator())
            else
              GoogleMap(
                key: const ValueKey('event_location_picker_map'),
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _selectedLatLng ?? _defaultLatLng,
                  zoom: 13,
                ),
                myLocationEnabled: !kIsWeb,
                myLocationButtonEnabled: true,
                onTap: _onMapTap,
                markers: {
                  if (_selectedLatLng != null)
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedLatLng!,
                      infoWindow: InfoWindow(
                        title: _selectedPlaceName ?? 'Event location',
                        snippet: _selectedAddress,
                      ),
                    ),
                },
              ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : (_searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _suggestions = []);
                                    },
                                  )),
                        hintText:
                            'Search for parks, venues, dog-friendly spots',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title:
                                Text(suggestion.structuredFormatting.mainText),
                            subtitle: Text(
                                suggestion.structuredFormatting.secondaryText),
                            onTap: () => _onSuggestionSelected(suggestion),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected location',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedLatLng != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedPlaceName != null)
                              Text(_selectedPlaceName!,
                                  style: theme.textTheme.titleLarge),
                            if (_selectedAddress != null)
                              Text(_selectedAddress!,
                                  style: theme.textTheme.bodyMedium),
                            Text(
                              '${_selectedLatLng!.latitude.toStringAsFixed(5)}, ${_selectedLatLng!.longitude.toStringAsFixed(5)}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Tap on the map to choose where your event will happen.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _confirmSelection,
                        icon: const Icon(Icons.check),
                        label: const Text('Use this location'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // Close GestureDetector
    );
  }
}
