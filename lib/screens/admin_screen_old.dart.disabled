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

  void _onGooglePlaceSelected(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      setState(() {
        _latitude = double.parse(prediction.lat!);
        _longitude = double.parse(prediction.lng!);
        _nameController.text = prediction.description?.split(',').first ?? '';
        _addressController.text = prediction.description ?? '';
      });

      // Fetch additional Google Places details
      try {
        final placeDetails = await PlacesService.getPlaceDetails(prediction.placeId!);
        if (placeDetails != null) {
          setState(() {
            _googlePlaceData = placeDetails;
            if (placeDetails['rating'] != null) {
              _rating = placeDetails['rating'].toDouble();
            }
          });
          
          // Get photos
          final photos = await PlacesService.getPlacePhotos(prediction.placeId!);
          setState(() {
            _photoUrls = photos;
          });
        }
      } catch (e) {
        debugPrint('Error fetching place details: $e');
      }
    }
  }

  Future<void> _saveFeaturedPark() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location from Google Places')),
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
        'google_place_data': _googlePlaceData, // Store Google data for reference
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
    _searchController.clear();
    setState(() {
      _latitude = null;
      _longitude = null;
      _rating = 4.0;
      _selectedAmenities.clear();
      _photoUrls.clear();
      _googlePlaceData = null;
    });
  }

  Future<void> _deletePark(String parkId) async {
    try {
      await ParkService.deleteFeaturedPark(parkId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Park deleted successfully')),
      );
      _loadExistingParks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting park: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Manage Featured Parks'),
        backgroundColor: const Color(0xFF2E7D32), // Bark green
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        color: Color(0xFF2E7D32),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Featured Parks Management',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add curated dog parks that will be featured prominently in the map with special branding and enhanced details.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF2E7D32).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add New Park Form
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Featured Park',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Google Places Search
                      Text(
                        'Search Google Places',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GooglePlaceAutoCompleteTextField(
                        textEditingController: _searchController,
                        googleAPIKey: const String.fromEnvironment('GOOGLE_PLACES_API_KEY', defaultValue: 'AIzaSyCMfjL_HJ22QOnNTDCX2idk25cjg9lv2IY'),
                        inputDecoration: InputDecoration(
                          hintText: 'Search for dog parks on Google...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                          ),
                        ),
                        debounceTime: 800,
                        countries: const ["us"],
                        isLatLngRequired: true,
                        getPlaceDetailWithLatLng: (Prediction prediction) {
                          _onGooglePlaceSelected(prediction);
                        },
                        itemClick: (Prediction prediction) {
                          _searchController.text = prediction.description!;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Google Place Data Preview
                      if (_googlePlaceData != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Google Places Data Found',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_googlePlaceData!['rating'] != null)
                                Text('Google Rating: ${_googlePlaceData!['rating']} ⭐'),
                              if (_googlePlaceData!['user_ratings_total'] != null)
                                Text('Reviews: ${_googlePlaceData!['user_ratings_total']}'),
                              if (_googlePlaceData!['opening_hours'] != null)
                                const Text('Hours: Available'),
                              const SizedBox(height: 4),
                              Text(
                                'This data will be combined with your custom information.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Custom Park Details
                      Text(
                        'Custom Park Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Park Name*',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the park name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Custom Description',
                          hintText: 'Add your own description that complements Google\'s data...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                          ),
                        ),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),

                      // Rating
                      Row(
                        children: [
                          Text(
                            'Your Rating: ',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Expanded(
                            child: Slider(
                              value: _rating,
                              min: 1.0,
                              max: 5.0,
                              divisions: 8,
                              activeColor: const Color(0xFF2E7D32),
                              label: _rating.toString(),
                              onChanged: (value) {
                                setState(() => _rating = value);
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _rating.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Amenities
                      Text(
                        'Park Amenities',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2E7D32),
                            checkmarkColor: Colors.white,
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

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveFeaturedPark,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Add Featured Park',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Existing Parks List
            Text(
              'Existing Featured Parks (${_existingParks.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_existingParks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.park,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No featured parks yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Add your first featured park above',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._existingParks.map((park) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    park['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(park['address'] ?? 'No address'),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.orange),
                          Text(' ${park['rating']} • '),
                          Text('${(park['amenities'] as List?)?.length ?? 0} amenities'),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(park),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> park) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Featured Park'),
        content: Text('Are you sure you want to remove "${park['name']}" from featured parks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePark(park['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
