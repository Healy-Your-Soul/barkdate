import 'package:flutter/material.dart';

class UnifiedMapService {
  static Future<Map<String, dynamic>?> showLocationPicker({
    required BuildContext context,
    String title = 'Select Location',
    String? initialLocation,
    double? initialLatitude,
    double? initialLongitude,
  }) async {
    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationPickerSheet(
        title: title,
        initialLocation: initialLocation,
        initialLatitude: initialLatitude,
        initialLongitude: initialLongitude,
      ),
    );
  }
}

class LocationPickerSheet extends StatefulWidget {
  final String title;
  final String? initialLocation;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerSheet({
    super.key,
    required this.title,
    this.initialLocation,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedLocation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _searchController.text = widget.initialLocation!;
      _selectedLocation = {
        'name': widget.initialLocation,
        'latitude': widget.initialLatitude,
        'longitude': widget.initialLongitude,
      };
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For now, use mock data until PlacesService is implemented
      final results = await _getMockPlaces(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _searchResults = [];
      });
      debugPrint('Error searching places: $e');
    }
  }

  // Mock data for places - replace with actual PlacesService.searchPlaces when ready
  Future<List<Map<String, dynamic>>> _getMockPlaces(String query) async {
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate network delay

    final mockPlaces = [
      {
        'place_id': '1',
        'name': 'Central Park Dog Run',
        'address': '830 5th Ave, New York, NY 10065',
        'latitude': 40.7812,
        'longitude': -73.9665,
      },
      {
        'place_id': '2',
        'name': 'Prospect Park Dog Beach',
        'address': 'Prospect Park, Brooklyn, NY 11225',
        'latitude': 40.6602,
        'longitude': -73.9690,
      },
      {
        'place_id': '3',
        'name': 'Washington Square Park',
        'address': 'Washington Square, New York, NY 10012',
        'latitude': 40.7308,
        'longitude': -73.9973,
      },
      {
        'place_id': '4',
        'name': 'Bryant Park',
        'address': '42nd St & 6th Ave, New York, NY 10018',
        'latitude': 40.7536,
        'longitude': -73.9832,
      },
      {
        'place_id': '5',
        'name': 'Madison Square Park',
        'address': '11 Madison Ave, New York, NY 10010',
        'latitude': 40.7414,
        'longitude': -73.9877,
      },
    ];

    return mockPlaces
        .where((place) =>
            (place['name'] as String?)
                    ?.toLowerCase()
                    .contains(query.toLowerCase()) ==
                true ||
            (place['address'] as String?)
                    ?.toLowerCase()
                    .contains(query.toLowerCase()) ==
                true)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for parks, cafes, or addresses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _selectedLocation = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchPlaces(value);
              },
            ),
          ),

          // Search results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'Search for a location above',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          final isSelected = _selectedLocation?['place_id'] ==
                              place['place_id'];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              child: Icon(
                                Icons.location_on,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(place['name'] ?? 'Unknown'),
                            subtitle: Text(place['address'] ?? ''),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            selected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedLocation = place;
                                _searchController.text = place['name'] ?? '';
                              });
                            },
                          );
                        },
                      ),
          ),

          // Confirm button
          if (_selectedLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedLocation);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Select ${_selectedLocation!['name']}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
