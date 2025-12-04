import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/screens/map_v2/providers/map_selection_provider.dart';
import 'package:barkdate/screens/map_v2/providers/map_viewport_provider.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/services/events_service.dart';
import 'package:barkdate/services/gemini_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/widgets/checkin_button.dart';
import 'package:barkdate/models/event.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
            .where((e) => e.latitude == selection.selectedPlace!.latitude &&
                e.longitude == selection.selectedPlace!.longitude)
            .toList(),
        onCheckInSuccess: onCheckInSuccess,
      );
    }

    // Temporarily disabled - EventDetailsSheet has compilation issues
    // if (selection.selectedEvent != null) {
    //   return EventDetailsSheet(event: selection.selectedEvent!);
    // }

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
  bool _isLoadingCheckIns = false;

  @override
  void initState() {
    super.initState();
    _loadActiveCheckIns();
  }

  Future<void> _loadActiveCheckIns() async {
    setState(() => _isLoadingCheckIns = true);
    try {
      final checkIns = await CheckInService.getActiveCheckInsAtPlace(widget.place.placeId);
      if (mounted) {
        setState(() {
          _activeCheckIns = checkIns;
          _isLoadingCheckIns = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading active check-ins: $e');
      if (mounted) {
        setState(() => _isLoadingCheckIns = false);
      }
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
                            final user = checkIn['user'] as Map<String, dynamic>?;
                            final dog = checkIn['dog'] as Map<String, dynamic>?;
                            final checkedInAt = DateTime.parse(checkIn['checked_in_at']);
                            final duration = DateTime.now().difference(checkedInAt);
                            
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
                              trailing: user?['username'] != null
                                  ? Text(
                                      '@${user!['username']}',
                                      style: Theme.of(context).textTheme.bodySmall,
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
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
                        ref.read(mapSelectionProvider.notifier).clearSelection();
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Open/Rating status row
                    Row(
                      children: [
                        // Open Now badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.place.isOpen ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.place.isOpen ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.place.isOpen ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              color: widget.place.isOpen ? Colors.green.shade700 : Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Rating
                        if (widget.place.rating > 0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.place.rating}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Category row
                    Row(
                      children: [
                        const Text('Categories: ',
                            style: TextStyle(color: Colors.grey)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.place.category.displayName.toLowerCase(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Check In Button (prominent)
                    CheckInButton(
                      parkId: widget.place.placeId,
                      parkName: widget.place.name,
                      onCheckInSuccess: () {
                        if (widget.onCheckInSuccess != null) {
                          widget.onCheckInSuccess!();
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Who's Here Now section
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
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Who\'s Here Now',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${widget.dogCount} ${widget.dogCount == 1 ? 'dog' : 'dogs'} checked in',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showActiveCheckInsDialog,
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Upcoming Events section
                    if (widget.events.isNotEmpty) ...[
                      const Text(
                        'Upcoming Events',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.events.map((event) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primaryContainer,
                                child: Text(event.categoryIcon),
                              ),
                              title: Text(event.title),
                              subtitle: Text(event.formattedDate),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                ref
                                    .read(mapSelectionProvider.notifier)
                                    .selectEvent(event);
                              },
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

    final viewport = ref.read(mapViewportProvider);
    final center = viewport.center;

    try {
      final response = await _geminiService!.askAboutPlaces(
        query: query,
        latitude: center.latitude,
        longitude: center.longitude,
      );

      setState(() {
        _response = response;
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
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Map Assistant',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        ref.read(mapSelectionProvider.notifier).clearSelection();
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
