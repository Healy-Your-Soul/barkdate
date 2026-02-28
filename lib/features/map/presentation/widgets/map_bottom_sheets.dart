import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/map/presentation/providers/map_provider.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/gemini_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/widgets/plan_walk_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main bottom sheet manager for map selections
class MapBottomSheets extends ConsumerWidget {
  final List<PlaceResult> places;
  final List<Event> events;
  final Map<String, int> checkInCounts;
  final VoidCallback? onCheckInSuccess;

  const MapBottomSheets({
    super.key,
    required this.places,
    required this.events,
    required this.checkInCounts,
    this.onCheckInSuccess,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(mapSelectionProvider);

    if (selection.selectedPlace != null) {
      final dogCount = checkInCounts[selection.selectedPlace!.placeId] ?? 0;
      return PlaceDetailsSheet(
        place: selection.selectedPlace!,
        dogCount: dogCount,
        events: events
            .where((e) =>
                e.latitude == selection.selectedPlace!.latitude &&
                e.longitude == selection.selectedPlace!.longitude)
            .toList(),
        onCheckInSuccess: onCheckInSuccess,
      );
    }

    if (selection.showAiAssistant) {
      return const GeminiAssistantSheet();
    }

    return const SizedBox.shrink();
  }
}

/// Place details bottom sheet
class PlaceDetailsSheet extends ConsumerStatefulWidget {
  final PlaceResult place;
  final int dogCount;
  final List<Event> events;
  final VoidCallback? onCheckInSuccess;

  const PlaceDetailsSheet({
    super.key,
    required this.place,
    required this.dogCount,
    required this.events,
    this.onCheckInSuccess,
  });

  @override
  ConsumerState<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends ConsumerState<PlaceDetailsSheet> {
  List<Map<String, dynamic>> _activeCheckIns = [];

  @override
  void initState() {
    super.initState();
    _loadActiveCheckIns();
  }

  Future<void> _loadActiveCheckIns() async {
    try {
      final checkIns =
          await CheckInService.getActiveCheckInsAtPlace(widget.place.placeId);
      if (mounted) {
        setState(() {
          _activeCheckIns = checkIns;
        });
      }
    } catch (e) {
      debugPrint('Error loading active check-ins: $e');
    }
  }

  void _showActiveCheckInsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Who\'s Here Now',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _activeCheckIns.isEmpty
                      ? const Center(
                          child: Text('No one is checked in right now'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _activeCheckIns.length,
                          itemBuilder: (context, index) {
                            final checkIn = _activeCheckIns[index];
                            final user =
                                checkIn['user'] as Map<String, dynamic>?;
                            final dog = checkIn['dog'] as Map<String, dynamic>?;
                            final checkedInAt =
                                DateTime.parse(checkIn['checked_in_at']);
                            final duration =
                                DateTime.now().difference(checkedInAt);

                            String timeAgo;
                            if (duration.inMinutes < 1) {
                              timeAgo = 'Just now';
                            } else if (duration.inMinutes < 60) {
                              timeAgo = '${duration.inMinutes}m ago';
                            } else {
                              timeAgo = '${duration.inHours}h ago';
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: dog?['main_photo_url'] != null
                                    ? NetworkImage(dog!['main_photo_url'])
                                    : null,
                                child: dog?['main_photo_url'] == null
                                    ? const Icon(Icons.pets)
                                    : null,
                              ),
                              title: Text(dog?['name'] ?? 'Unknown Dog'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (dog?['breed'] != null)
                                    Text(dog!['breed']),
                                  Text('Checked in $timeAgo'),
                                ],
                              ),
                              trailing: user?['name'] != null
                                  ? Text(
                                      user!['name'],
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Open directions in external maps app
  Future<void> _openDirections() async {
    final lat = widget.place.latitude;
    final lng = widget.place.longitude;
    final name = Uri.encodeComponent(widget.place.name);

    // Try opening in Apple Maps on iOS, Google Maps on Android
    Uri mapsUrl;
    if (Platform.isIOS) {
      mapsUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$name');
    } else {
      mapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=${widget.place.placeId}');
    }

    try {
      if (await canLaunchUrl(mapsUrl)) {
        await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Google Maps web
        final fallback = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening directions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps app')),
        );
      }
    }
  }

  /// Build place tags section for user contributions
  Widget _buildPlaceTagsSection() {
    // Common place amenity tags
    final List<Map<String, dynamic>> availableTags = [
      {
        'id': 'dog_friendly',
        'icon': Icons.pets,
        'label': 'Dog Friendly',
        'color': Colors.green
      },
      {
        'id': 'water',
        'icon': Icons.water_drop,
        'label': 'Water Available',
        'color': Colors.blue
      },
      {
        'id': 'poo_bags',
        'icon': Icons.shopping_bag,
        'label': 'Poo Bags',
        'color': Colors.brown
      },
      {
        'id': 'garbage',
        'icon': Icons.delete,
        'label': 'Trash Bins',
        'color': Colors.grey
      },
      {
        'id': 'fenced',
        'icon': Icons.fence,
        'label': 'Fenced Area',
        'color': Colors.orange
      },
      {
        'id': 'shade',
        'icon': Icons.wb_shade,
        'label': 'Shade Available',
        'color': Colors.teal
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Amenities',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddTagDialog(availableTags),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Tag'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Show existing tags (would come from DB in production)
            if (widget.place.isDogFriendly)
              _buildTagChip(Icons.pets, 'Dog Friendly', Colors.green),
            // Show demo amenity tags for the place
            _buildTagChip(Icons.water_drop, 'Water', Colors.blue),
            _buildTagChip(Icons.delete, 'Trash Bins', Colors.grey),
            _buildTagChip(Icons.wb_shade, 'Shade', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildTagChip(IconData icon, String label, Color color, {int? count}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddTagDialog(List<Map<String, dynamic>> tags) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Amenity Tag',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help other dog owners know what\'s available here',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: tags
                  .map((tag) => ActionChip(
                        avatar: Icon(tag['icon'] as IconData,
                            size: 18, color: tag['color'] as Color),
                        label: Text(tag['label'] as String),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Tagged as "${tag['label']}"! Thank you! 🐕'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // TODO: Save tag to database
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.place.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref
                            .read(mapSelectionProvider.notifier)
                            .clearSelection();
                      },
                    ),
                  ],
                ),
              ),

              // Content - scrollable list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 1. Check-in button
                    AnimatedCheckInButton(
                      parkId: widget.place.placeId,
                      parkName: widget.place.name,
                      latitude: widget.place.latitude,
                      longitude: widget.place.longitude,
                      onCheckInSuccess: widget.onCheckInSuccess,
                    ),
                    const SizedBox(height: 10),

                    // Plan a Walk button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showPlanWalkSheet(
                            context,
                            parkId: widget.place.placeId,
                            parkName: widget.place.name,
                            latitude: widget.place.latitude,
                            longitude: widget.place.longitude,
                          );
                        },
                        icon: const Text('🕐', style: TextStyle(fontSize: 16)),
                        label: const Text('Plan a Walk'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(color: Color(0xFF0D47A1)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Open/Rating status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.place.isOpen
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.place.isOpen
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          child: Text(
                            widget.place.isOpen ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              color: widget.place.isOpen
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.place.rating > 0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('${widget.place.rating}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Category
                    Row(
                      children: [
                        const Text('Categories: ',
                            style: TextStyle(color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF4CAF50).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.place.category.displayName.toLowerCase(),
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Dog-Friendly Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.place.isDogFriendly
                            ? (widget.place.isFeaturedPark
                                ? Colors.green.shade50
                                : Colors.orange.shade50)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.place.isDogFriendly
                              ? (widget.place.isFeaturedPark
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.place.isFeaturedPark
                                ? Icons.verified
                                : (widget.place.isDogFriendly
                                    ? Icons.pets
                                    : Icons.help_outline),
                            size: 20,
                            color: widget.place.isDogFriendly
                                ? (widget.place.isFeaturedPark
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700)
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.place.dogFriendlyStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: widget.place.isDogFriendly
                                        ? (widget.place.isFeaturedPark
                                            ? Colors.green.shade800
                                            : Colors.orange.shade800)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                if (!widget.place.isDogFriendly)
                                  Text('Call ahead to confirm dogs are welcome',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Photo
                    if (widget.place.photoReference != null &&
                        widget.place.photoReference!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 150,
                          width: double.infinity,
                          child: Image.network(
                            PlacesService.getPhotoUrl(
                                widget.place.photoReference!,
                                maxWidth: 600),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                  child: Icon(Icons.park,
                                      size: 48, color: Colors.grey.shade400)),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6. Get Directions
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openDirections,
                        icon: const Icon(Icons.directions),
                        label: const Text('Get Directions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. Place Tags
                    _buildPlaceTagsSection(),
                    const SizedBox(height: 20),

                    // 8. Who's Here Now
                    if (widget.dogCount > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.pets,
                                    color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Who\'s Here Now',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(
                                      '${widget.dogCount} ${widget.dogCount == 1 ? 'dog' : 'dogs'} checked in',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                          TextButton(
                              onPressed: _showActiveCheckInsDialog,
                              child: const Text('See all')),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 9. Events
                    if (widget.events.isNotEmpty) ...[
                      const Text('Upcoming Events',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      ...widget.events.map((event) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Text(event.categoryIcon),
                              ),
                              title: Text(event.title),
                              subtitle: Text(event.formattedDate),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => ref
                                  .read(mapSelectionProvider.notifier)
                                  .selectEvent(event),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Gemini AI assistant bottom sheet
class GeminiAssistantSheet extends ConsumerStatefulWidget {
  const GeminiAssistantSheet({super.key});

  @override
  ConsumerState<GeminiAssistantSheet> createState() =>
      _GeminiAssistantSheetState();
}

class _GeminiAssistantSheetState extends ConsumerState<GeminiAssistantSheet> {
  final TextEditingController _controller = TextEditingController();
  GeminiResponse? _response;
  bool _isLoading = false;
  GeminiService? _geminiService;

  @override
  void initState() {
    super.initState();
    // TODO: Get API key from environment/secure storage
    const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (apiKey.isNotEmpty) {
      _geminiService = GeminiService(apiKey: apiKey);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQuery(String query) async {
    if (_geminiService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini API key not configured')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
    });

    // Clear previous AI suggestions
    ref.read(mapFiltersProvider.notifier).clearAiSuggestions();

    final viewport = ref.read(mapViewportProvider);
    final center = viewport.center;

    try {
      final response = await _geminiService!.askAboutPlaces(
        query: query,
        latitude: center.latitude,
        longitude: center.longitude,
      );

      String displayText = response.text;
      List<String> suggestedPlaceNames = [];

      // Try to parse JSON
      try {
        // Clean up response text if it contains markdown code blocks
        String jsonString = response.text;
        if (jsonString.contains('```json')) {
          jsonString =
              jsonString.replaceAll('```json', '').replaceAll('```', '');
        } else if (jsonString.contains('```')) {
          jsonString = jsonString.replaceAll('```', '');
        }

        jsonString = jsonString.trim();

        final Map<String, dynamic> json = jsonDecode(jsonString);
        if (json.containsKey('response_text')) {
          displayText = json['response_text'];
        }
        if (json.containsKey('suggested_places')) {
          final List<dynamic> places = json['suggested_places'];
          suggestedPlaceNames =
              places.map((p) => p['name'].toString()).toList();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse AI JSON: $e');
        // Fallback to raw text is already set in displayText
      }

      // Update Map Filters if we have suggestions
      if (suggestedPlaceNames.isNotEmpty) {
        debugPrint('🤖 AI Suggested Places: $suggestedPlaceNames');
        ref
            .read(mapFiltersProvider.notifier)
            .setAiSuggestions(suggestedPlaceNames);

        // Trigger a refresh of the map data to search for these places
        ref.refresh(mapDataProvider);
      }

      setState(() {
        _response =
            GeminiResponse(text: displayText, sources: response.sources);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Map Assistant',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                          ),
                          Text(
                            'Ask about dog-friendly spots',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () {
                        ref
                            .read(mapSelectionProvider.notifier)
                            .clearSelection();
                      },
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Input field
                    TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask about dog-friendly spots...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            if (_controller.text.trim().isNotEmpty) {
                              _handleQuery(_controller.text.trim());
                              _controller.clear();
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _handleQuery(value.trim());
                          _controller.clear();
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Loading or response
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Thinking...'),
                            ],
                          ),
                        ),
                      )
                    else if (_response != null) ...[
                      // Response text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _response!.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),

                      // Sources
                      if (_response!.sources.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Sources:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ..._response!.sources.map((source) => ListTile(
                              leading: const Icon(Icons.link),
                              title: Text(source.title),
                              subtitle: Text(
                                source.uri,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                // TODO: Open link
                              },
                            )),
                      ],
                    ] else ...[
                      // Empty state
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'I can help you find parks, cafes, and events for you and your dog!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Quick replies
                    if (!_isLoading)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: GeminiService.quickReplies
                            .map(
                              (reply) => ActionChip(
                                label: Text(reply),
                                onPressed: () => _handleQuery(reply),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated Check-in button with green/red color transition
class AnimatedCheckInButton extends StatefulWidget {
  final String parkId;
  final String parkName;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onCheckInSuccess;

  const AnimatedCheckInButton({
    super.key,
    required this.parkId,
    required this.parkName,
    this.latitude,
    this.longitude,
    this.onCheckInSuccess,
  });

  @override
  State<AnimatedCheckInButton> createState() => _AnimatedCheckInButtonState();
}

class _AnimatedCheckInButtonState extends State<AnimatedCheckInButton> {
  bool _isCheckedIn = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted && checkIn != null && checkIn.parkId == widget.parkId) {
        setState(() => _isCheckedIn = true);
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
    }
  }

  Future<void> _toggleCheckIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (_isCheckedIn) {
        // Check out
        final success = await CheckInService.checkOut();
        if (success && mounted) {
          setState(() => _isCheckedIn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Checked out! See you next time 🐾'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } else {
        // Check in
        final checkIn = await CheckInService.checkInAtPark(
          parkId: widget.parkId,
          parkName: widget.parkName,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
        if (checkIn != null && mounted) {
          setState(() => _isCheckedIn = true);
          widget.onCheckInSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Woof! Checked in at ${widget.parkName}! 🐕'),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor =
        _isCheckedIn ? const Color(0xFFF44336) : const Color(0xFF4CAF50);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _toggleCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(_isCheckedIn ? Icons.logout : Icons.pets, size: 20),
        label: Text(
          _isLoading
              ? (_isCheckedIn ? 'Leaving...' : 'Checking in...')
              : (_isCheckedIn ? 'Check Out' : 'Check In'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
