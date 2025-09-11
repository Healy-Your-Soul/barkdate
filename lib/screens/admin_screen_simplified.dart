import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:barkdate/services/park_service.dart';

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
  
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  List<String> _selectedAmenities = [];
  double _rating = 4.0;
  List<String> _photoUrls = [];
  List<Map<String, dynamic>> _existingParks = [];
  
  // Map related
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};
  
  // Available amenities
  final List<String> _availableAmenities = [
    'off_leash_area',
    'agility_equipment', 
    'separate_small_dog_area',
    'water_fountain',
    'waste_stations',
    'benches',
    'shade_trees',
    'parking',
    'lighting',
    'fenced',
    'water_access',
    'toys_available',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingParks();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      final locationData = await location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadExistingParks() async {
    try {
      final parks = await ParkService.getFeaturedParks();
      if (mounted) {
        setState(() {
          _existingParks = parks;
        });
      }
    } catch (e) {
      debugPrint('Error loading parks: $e');
    }
  }

  Future<void> _saveFeaturedPark() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parkData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'latitude': _latitude!,
        'longitude': _longitude!,
        'address': _addressController.text.trim(),
        'amenities': _selectedAmenities,
        'rating': _rating,
        'photo_urls': _photoUrls,
        'is_active': true,
      };

      await ParkService.addFeaturedPark(parkData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Featured park added successfully!')),
        );
        _clearForm();
        _loadExistingParks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding park: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _addressController.clear();
    setState(() {
      _latitude = null;
      _longitude = null;
      _selectedAmenities.clear();
      _rating = 4.0;
      _photoUrls.clear();
      _selectedLocation = null;
      _markers.clear();
    });
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _latitude = position.latitude;
      _longitude = position.longitude;
      
      _markers.clear();
      _markers.add(Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Selected Location'),
      ));
    });
  }

  Future<void> _deletePark(String parkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Park'),
        content: const Text('Are you sure you want to delete this featured park?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ParkService.deleteFeaturedPark(parkId);
        _loadExistingParks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Park deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting park: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Featured Parks'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, 
                               color: Color(0xFF2E7D32), size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Add Featured Park',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create curated dog parks with enhanced details for all users to discover.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Selection with Map
                  Text(
                    'Select Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap on the map to select the park location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation ?? const LatLng(40.7829, -73.9654),
                          zoom: 12,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: _markers,
                        onTap: _onMapTapped,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                      ),
                    ),
                  ),
                  
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, 
                                 color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Basic Information
                  Text(
                    'Park Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Park Name *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.park),
                    ),
                    validator: (value) => value?.isEmpty == true ? 'Required' : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Rating
                  Text(
                    'Rating: ${_rating.toStringAsFixed(1)} ⭐',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Slider(
                    value: _rating,
                    min: 1.0,
                    max: 5.0,
                    divisions: 8,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Amenities
                  Text(
                    'Amenities',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableAmenities.map((amenity) {
                      final isSelected = _selectedAmenities.contains(amenity);
                      return FilterChip(
                        label: Text(
                          amenity.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                            fontSize: 12,
                          ),
                        ),
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
                        selectedColor: const Color(0xFF2E7D32),
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveFeaturedPark,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_location),
                      label: Text(_isLoading ? 'Adding Park...' : 'Add Featured Park'),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Existing Parks
            Text(
              'Existing Featured Parks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_existingParks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.park_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No featured parks yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first featured park using the form above',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...._existingParks.map((park) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.star, color: Colors.white),
                  ),
                  title: Text(
                    park['name'] ?? 'Unnamed Park',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (park['address'] != null) 
                        Text(park['address']),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${park['rating']?.toStringAsFixed(1) ?? 'N/A'}'),
                          const SizedBox(width: 16),
                          Text(
                            '${(park['amenities'] as List?)?.length ?? 0} amenities',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePark(park['id']),
                  ),
                  isThreeLine: true,
                ),
              )),
          ],
        ),
      ),
    );
  }
}
