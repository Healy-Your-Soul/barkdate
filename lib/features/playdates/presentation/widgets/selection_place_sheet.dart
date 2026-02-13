import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// A simplified place sheet for selecting a location in the Map Picker
class SelectionPlaceSheet extends StatefulWidget {
  final PlaceResult place;
  final ScrollController scrollController;
  final VoidCallback? onClose;
  final VoidCallback? onSelect; // Callback when "Select This Location" is tapped

  const SelectionPlaceSheet({
    super.key,
    required this.place,
    required this.scrollController,
    this.onClose,
    this.onSelect,
  });

  @override
  State<SelectionPlaceSheet> createState() => _SelectionPlaceSheetState();
}

class _SelectionPlaceSheetState extends State<SelectionPlaceSheet> {
  bool _isLoading = true;
  int _dogCount = 0;
  List<Map<String, dynamic>> _amenities = [];
  bool _showAllAmenities = false;

  @override
  void initState() {
    super.initState();
    _loadPlaceDetails();
  }

  Future<void> _loadPlaceDetails() async {
    try {
      // Load dog count
      final count = await CheckInService.getParkDogCount(widget.place.placeId);
      
      // Load amenities
      final amenitiesData = await SupabaseConfig.client.rpc(
        'get_place_amenities',
        params: {'p_place_id': widget.place.placeId},
      );
      
      if (mounted) {
        setState(() {
          _dogCount = count;
          if (amenitiesData != null) {
            _amenities = List<Map<String, dynamic>>.from(amenitiesData);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading place details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Build amenities section with chips (ReadOnly)
  Widget _buildAmenitiesSection() {
    final suggestedAmenities = _amenities.where((a) => (a['suggested_count'] as int? ?? 0) > 0).toList();
    
    if (suggestedAmenities.isEmpty) return const SizedBox.shrink();
    
    final displayCount = _showAllAmenities ? suggestedAmenities.length : 4;
    final displayList = suggestedAmenities.take(displayCount).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...displayList.map((amenity) => Chip(
              avatar: Text(amenity['icon'] ?? '✓', style: const TextStyle(fontSize: 14)),
              label: Text(
                amenity['name'] ?? '',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            if (suggestedAmenities.length > 4 && !_showAllAmenities)
              ActionChip(
                label: Text('+${suggestedAmenities.length - 4} more'),
                onPressed: () => setState(() => _showAllAmenities = true),
                backgroundColor: Colors.grey.shade100,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Get color for category
  Color _getCategoryColor(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.park: return Colors.green;
      case PlaceCategory.restaurant: return Colors.orange;
      case PlaceCategory.petStore: return Colors.blue;
      case PlaceCategory.veterinary: return Colors.red;
      default: return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Extra padding for fixed button
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.place.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DOG COUNT (Simple display)
                if (_dogCount > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '$_dogCount ${_dogCount == 1 ? 'dog' : 'dogs'} here now',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // STATUS ROW
                Row(
                  children: [
                    if (widget.place.isOpen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          'Open Now',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (widget.place.rating > 0) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        widget.place.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // CATEGORY
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(widget.place.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.place.category.displayName,
                    style: TextStyle(color: _getCategoryColor(widget.place.category), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),

                // DOG FRIENDLY INFO (ReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.place.isDogFriendly ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.place.isDogFriendly ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.place.isDogFriendly ? Icons.check_circle : Icons.help_outline,
                        color: widget.place.isDogFriendly ? Colors.green : Colors.red.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.place.isDogFriendly ? 'Dog Friendly' : 'Check if dog-friendly',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildAmenitiesSection(),

                // PHOTO
                if (widget.place.photoReference != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      PlacesService.getPhotoUrl(widget.place.photoReference!, maxWidth: 600),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.image, size: 40)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ADDRESS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.place.address,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // FIXED BOTTOM BAR BUTTON
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: widget.onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Select This Location',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_outline),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
