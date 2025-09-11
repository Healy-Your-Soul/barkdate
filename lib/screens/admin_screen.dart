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
  final _searchController = TextEditingController();
  
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  List<FeaturedPark> _featuredParks = [];
  List<PlaceAutocomplete> _searchResults = [];
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

  Future<void> _loadFeaturedParks() async {
    setState(() => _isLoading = true);
    try {
      final parkData = await ParkService.getFeaturedParks();
      final parks = parkData.map((data) => FeaturedPark.fromJson(data)).toList();
      setState(() => _featuredParks = parks);
    } catch (e) {
      _showError('Failed to load featured parks: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    if (value.length < 3) return; // Wait for at least 3 characters

    try {
      final results = await PlacesService.autocomplete(value);
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
      });
    } catch (e) {
      print('Search error: $e');
    }
  }

  void _onPlaceSelected(PlaceAutocomplete place) async {
    setState(() => _isLoading = true);
    try {
      final details = await PlacesService.getPlaceDetailsByPlaceId(place.placeId);
      if (details != null && details['geometry'] != null) {
        final location = details['geometry']['location'];
        final latLng = LatLng(location['lat'], location['lng']);
        
        setState(() {
          _selectedLocation = latLng;
          _nameController.text = details['name'] ?? place.structuredFormatting.mainText;
          _showSearchResults = false;
          _searchController.clear();
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16),
        );
      }
    } catch (e) {
      _showError('Failed to get place details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  Future<void> _savePark() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) {
      _showError('Please fill all fields and select a location');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ParkService.addFeaturedPark({
        'name': _nameController.text,
        'description': _descriptionController.text,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'amenities': _selectedAmenities.toList(),
        'is_active': true,
      });

      _clearForm();
      await _loadFeaturedParks();
      _showSuccess('Park added successfully!');
    } catch (e) {
      _showError('Failed to save park: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    _searchController.clear();
    setState(() {
      _selectedLocation = null;
      _selectedAmenities.clear();
      _showSearchResults = false;
    });
  }

  Future<void> _deletePark(String parkId) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ParkService.deleteFeaturedPark(parkId);
        await _loadFeaturedParks();
        _showSuccess('Park deleted successfully!');
      } catch (e) {
        _showError('Failed to delete park: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF2E7D32)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Featured Parks Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAddParkCard(),
                  const SizedBox(height: 24),
                  _buildFeaturedParksList(),
                ],
              ),
            ),
    );
  }

  Widget _buildAddParkCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_location,
                      color: Color(0xFF2E7D32),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Featured Park',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Google Places Search
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Google Places',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (_showSearchResults && _searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            title: Text(place.structuredFormatting.mainText),
                            subtitle: Text(place.structuredFormatting.secondaryText),
                            onTap: () => _onPlaceSelected(place),
                            dense: true,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Map for location selection
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: _onMapTap,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(40.7128, -74.0060), // NYC default
                      zoom: 12,
                    ),
                    markers: _selectedLocation != null
                        ? {
                            Marker(
                              markerId: const MarkerId('selected'),
                              position: _selectedLocation!,
                              infoWindow: const InfoWindow(title: 'Selected Location'),
                            ),
                          }
                        : {},
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Park name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Park Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                ),
                validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2E7D32)),
                  ),
                ),
                validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Amenities
              const Text(
                'Amenities',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                    backgroundColor: Colors.grey[200],
                    selectedColor: const Color(0xFF2E7D32).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF2E7D32),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _savePark,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Save Park', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _clearForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedParksList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.list,
                    color: Color(0xFF2E7D32),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Featured Parks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_featuredParks.length} parks',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_featuredParks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No featured parks yet.\nAdd your first featured park above!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _featuredParks.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final park = _featuredParks[index];
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.park,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    title: Text(
                      park.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(park.description),
                        const SizedBox(height: 4),
                        if (park.amenities.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            children: park.amenities.take(3).map((amenity) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  amenity,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32)),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePark(park.id),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
