import 'package:flutter/material.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/event_card.dart';
import 'package:barkdate/screens/create_event_screen.dart';
import 'package:barkdate/screens/event_detail_screen.dart';
import 'package:barkdate/widgets/app_section_header.dart';
import 'package:barkdate/widgets/app_bottom_sheet.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/widgets/app_empty_state.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Event> _allEvents = [];
  List<Event> _myEvents = [];
  List<Event> _hostingEvents = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedCategory;
  bool _hasInitialized = false;

  final List<String> _categories = [
    'All',
    'Birthday',
    'Training',
    'Social',
    'Professional',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Don't load data here - wait for didChangeDependencies to ensure screen is visible
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only load once when screen becomes visible
    if (!_hasInitialized) {
      _hasInitialized = true;

      // Use post-frame callback to ensure screen is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEvents();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = SupabaseConfig.auth.currentUser;
      if (user == null) {
        // Show sample data for demo
        _loadSampleEvents();
        return;
      }

      // Check cache first and show immediately (Option A)
      final cachedAllEvents = CacheService().getCachedEventList('all_events');
      final cachedMyEvents =
          CacheService().getCachedEventList('my_events_${user.id}');
      final cachedHostingEvents =
          CacheService().getCachedEventList('hosting_events_${user.id}');

      if (cachedAllEvents != null ||
          cachedMyEvents != null ||
          cachedHostingEvents != null) {
        setState(() {
          if (cachedAllEvents != null)
            _allEvents = cachedAllEvents.cast<Event>();
          if (cachedMyEvents != null) _myEvents = cachedMyEvents.cast<Event>();
          if (cachedHostingEvents != null)
            _hostingEvents = cachedHostingEvents.cast<Event>();
          _isLoading = false;
        });
      }

      // Load all events
      final allEvents = await EventService.getUpcomingEvents();

      // Load user's participating events
      final myEvents = await EventService.getUserParticipatingEvents(user.id);

      // Load user's hosting events
      final hostingEvents = await EventService.getUserOrganizedEvents(user.id);

      // Cache the fresh data
      CacheService().cacheEventList('all_events', allEvents);
      CacheService().cacheEventList('my_events_${user.id}', myEvents);
      CacheService().cacheEventList('hosting_events_${user.id}', hostingEvents);

      setState(() {
        _allEvents = allEvents;
        _myEvents = myEvents;
        _hostingEvents = hostingEvents;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _loadSampleEvents(); // Fallback to sample data
      });
    }
  }

  void _loadSampleEvents() {
    final now = DateTime.now();
    setState(() {
      _allEvents = [
        Event(
          id: 'sample-1',
          title: 'Puppy Playtime at Central Park',
          description:
              'Join us for an energetic play session designed specifically for puppies under 1 year old. Great for socialization!',
          organizerId: 'sample-organizer-1',
          organizerType: 'user',
          organizerName: 'Sarah Johnson',
          organizerAvatarUrl: '',
          startTime: now.add(const Duration(days: 2, hours: 10)),
          endTime: now.add(const Duration(days: 2, hours: 12)),
          location: 'Central Park Dog Run',
          category: 'social',
          maxParticipants: 15,
          currentParticipants: 8,
          targetAgeGroups: ['puppy'],
          targetSizes: ['small', 'medium'],
          price: 0,
          photoUrls: [],
          requiresRegistration: true,
          visibility: 'public',
          status: 'upcoming',
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        Event(
          id: 'sample-2',
          title: 'Basic Obedience Training Class',
          description:
              'Learn fundamental commands like sit, stay, come, and heel. Perfect for dogs of all ages.',
          organizerId: 'sample-organizer-2',
          organizerType: 'professional',
          organizerName: 'Pawsitive Training Center',
          organizerAvatarUrl: '',
          startTime: now.add(const Duration(days: 5, hours: 18)),
          endTime: now.add(const Duration(days: 5, hours: 19)),
          location: 'Pawsitive Training Center',
          category: 'training',
          maxParticipants: 8,
          currentParticipants: 5,
          targetAgeGroups: ['adult', 'senior'],
          targetSizes: ['small', 'medium', 'large'],
          price: 45.00,
          photoUrls: [],
          requiresRegistration: true,
          visibility: 'public',
          status: 'upcoming',
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(days: 3)),
        ),
        Event(
          id: 'sample-3',
          title: 'Luna\'s 3rd Birthday Bash!',
          description:
              'Come celebrate Luna\'s birthday with cake, treats, and lots of playtime! All dogs welcome.',
          organizerId: 'sample-organizer-3',
          organizerType: 'user',
          organizerName: 'Mike Chen',
          organizerAvatarUrl: '',
          startTime: now.add(const Duration(days: 7, hours: 14)),
          endTime: now.add(const Duration(days: 7, hours: 17)),
          location: 'Golden Gate Park',
          category: 'birthday',
          maxParticipants: 20,
          currentParticipants: 12,
          targetAgeGroups: ['puppy', 'adult', 'senior'],
          targetSizes: ['small', 'medium', 'large'],
          price: 0,
          photoUrls: [],
          requiresRegistration: true,
          visibility: 'public',
          status: 'upcoming',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      _myEvents = [];
      _hostingEvents = [];
      _isLoading = false;
    });
  }

  List<Event> get _filteredEvents {
    if (_selectedCategory == null || _selectedCategory == 'All') {
      return _allEvents;
    }
    return _allEvents
        .where((event) =>
            event.category.toLowerCase() == _selectedCategory!.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateEventScreen()),
            ).then((_) => _loadEvents()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browse'),
            Tab(text: 'My Events'),
            Tab(text: 'Hosting'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBrowseTab(),
          _buildMyEventsTab(),
          _buildHostingTab(),
        ],
      ),
    );
  }

  Widget _buildBrowseTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _allEvents.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredEvents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: Column(
        children: [
          // Section header with filter action
          AppSectionHeader(
            title: 'Explore Events',
            action: AppButton(
              text: 'Filters',
              type: AppButtonType.outline,
              size: AppButtonSize.small,
              onPressed: _showFilterSheet,
            ),
          ),
          const SizedBox(height: 8),
          // Category filter chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Events list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                final event = _filteredEvents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EventCard(
                    event: event,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailScreen(event: event),
                      ),
                    ).then((_) => _loadEvents()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyEventsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse events and join some fun activities!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myEvents.length,
        itemBuilder: (context, index) {
          final event = _myEvents[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCard(
              event: event,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(event: event),
                ),
              ).then((_) => _loadEvents()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHostingTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hostingEvents.isEmpty) {
      return AppEmptyState(
        icon: Icons.event_note,
        title: 'No hosted events',
        message: 'Create your first event to bring the community together!',
        customAction: AppButton(
          text: 'Create Event',
          icon: Icons.add,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          ).then((_) => _loadEvents()),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _hostingEvents.length,
        itemBuilder: (context, index) {
          final event = _hostingEvents[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EventCard(
              event: event,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(event: event),
                ),
              ).then((_) => _loadEvents()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.event_available,
      title: 'No events found',
      message: 'Try adjusting your filters or check back later for new events.',
      actionText: 'Clear filters',
      onAction: () {
        setState(() {
          _selectedCategory = null;
        });
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load events',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadEvents,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width, // Full width on web
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'Filter Events',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Filter chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedCategory = null);
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
