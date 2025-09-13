import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../services/park_service.dart';
import '../models/featured_park.dart';
import '../services/places_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  List<FeaturedPark> _featuredParks = [];
  List<PlaceResult> _searchResults = [];
  bool _isLoading = false;
  bool _showSearchResults = false;
  Set<String> _selectedAmenities = {};

  final List<String> _availableAmenities = [
    'Fenced Area',
    'Water Station',
    'Waste Bags',
    'Parking',
    'Lighting',
    'Separate Small Dog Area',
    'Agility Equipment',
    'Benches',
    'Shade/Trees',
    'Restrooms',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeaturedParks();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedParks() async {
    setState(() => _isLoading = true);
    try {
      final parks = await ParkService.getFeaturedParks();
      setState(() => _featuredParks = parks);
    } catch (e) {
      _showError('Failed to load featured parks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get current location for search
      final location = Location();
      final currentLocation = await location.getLocation();
      
      final results = await PlacesService.searchDogFriendlyPlaces(
        latitude: currentLocation.latitude!,
        longitude: currentLocation.longitude!,
        keyword: query,
        radius: 10000,
      );
      
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
      });
    } catch (e) {
      _showError('Failed to search places: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectPlace(PlaceResult place) {
    setState(() {
      _nameController.text = place.name;
      _addressController.text = place.address;
      _selectedLocation = LatLng(place.latitude, place.longitude);
      _showSearchResults = false;
      _searchController.clear();
    });
    
    // Move map to selected location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_selectedLocation!, 16),
    );
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _saveFeaturedPark() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      _showError('Please fill all fields and select a location');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final park = FeaturedPark(
        id: '', // Will be set by Supabase
        name: _nameController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        rating: 0.0,
        reviewCount: 0,
        amenities: _selectedAmenities.toList(),
        photoUrls: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      await ParkService.addFeaturedPark(park);
      
      _clearForm();
      await _loadFeaturedParks();
      
      _showSuccess('Featured park added successfully!');
    } catch (e) {
      _showError('Failed to save park: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _addressController.clear();
    _searchController.clear();
    setState(() {
      _selectedLocation = null;
      _selectedAmenities.clear();
      _showSearchResults = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Park Administration'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Row(
        children: [
          // Left panel - Form
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Section
                      const Text(
                        'Search Places',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search for dog parks...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: _searchPlaces,
                      ),
                      
                      if (_showSearchResults) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              return ListTile(
                                title: Text(place.name),
                                subtitle: Text(place.address),
                                trailing: Text('⭐ ${place.rating.toStringAsFixed(1)}'),
                                onTap: () => _selectPlace(place),
                              );
                            },
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      
                      // Manual Entry Section
                      const Text(
                        'Add Featured Park',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Park Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a park name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Amenities Selection
                      const Text(
                        'Amenities',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableAmenities.map((amenity) {
                          final isSelected = _selectedAmenities.contains(amenity);
                          return FilterChip(
                            label: Text(amenity),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAmenities.add(amenity);
                                } else {
                                  _selectedAmenities.remove(amenity);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      
                      // Selected Location Info
                      if (_selectedLocation != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected Location:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}'),
                              Text('Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveFeaturedPark,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Save Park'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: _clearForm,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Divider(),
                      
                      // Featured Parks List
                      const Text(
                        'Featured Parks',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_featuredParks.isEmpty)
                        const Center(
                          child: Text('No featured parks added yet'),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _featuredParks.length,
                          itemBuilder: (context, index) {
                            final park = _featuredParks[index];
                            return Card(
                              child: ListTile(
                                title: Text(park.name),
                                subtitle: Text(park.address ?? 'No address provided'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    // TODO: Implement delete functionality
                                    _showError('Delete functionality not implemented yet');
                                  },
                                ),
                                onTap: () {
                                  // Move map to park location
                                  final location = LatLng(park.latitude, park.longitude);
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(location, 16),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Right panel - Map
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(37.7749, -122.4194), // San Francisco
                  zoom: 12,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                onTap: _onMapTap,
                markers: {
                  if (_selectedLocation != null)
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      infoWindow: const InfoWindow(title: 'Selected Location'),
                    ),
                  ..._featuredParks.map((park) => Marker(
                    markerId: MarkerId(park.id),
                    position: LatLng(park.latitude, park.longitude),
                    infoWindow: InfoWindow(title: park.name),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  )),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
