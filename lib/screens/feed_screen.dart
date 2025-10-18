import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/widgets/dog_card.dart';
import 'package:barkdate/widgets/filter_sheet.dart';
import 'package:barkdate/screens/catch_screen.dart';
import 'package:barkdate/screens/notifications_screen.dart';
import 'package:barkdate/widgets/photo_gallery.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/social_feed_screen.dart';
import 'package:barkdate/screens/dog_profile_detail.dart';
import 'package:barkdate/screens/settings_screen.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/widgets/playdate_request_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/notification_service.dart' as notif_service;
import 'package:barkdate/services/checkin_service.dart';
// Design system components
import 'package:barkdate/widgets/app_card.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/widgets/app_section_header.dart';
import 'package:barkdate/design_system/app_responsive.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/design_system/app_typography.dart';
// Events feature
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/models/event.dart';
// Cache service
import 'package:barkdate/services/cache_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FilterOptions _filterOptions = FilterOptions();
  bool _isRefreshing = false;
  bool _isLoading = true;
  List<Dog> _nearbyDogs = [];
  String? _error;
  int _upcomingPlaydates = 0;
  int _unreadNotifications = 0;
  int _mutualBarks = 0;
  bool _hasActiveCheckIn = false;
  List<Map<String, dynamic>> _upcomingFeedPlaydates = [];
  List<Event> _myEvents = [];
  List<Event> _suggestedEvents = [];
  List<Map<String, dynamic>> _friendDogs = [];

  @override
  void initState() {
    super.initState();
    
    // Load data immediately since Feed is the default tab
    Future.wait([
      _loadNearbyDogs(),
      _loadDashboardData(),
      _loadCheckInStatus(),
      _loadFeedSections(),
    ]).then((_) {
      _setupRealtimeSubscriptions();
    });
  }


  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  List<Dog> get _filteredDogs {
    return _nearbyDogs.where((dog) {
      // Distance filter
      if (dog.distanceKm > _filterOptions.maxDistance) return false;
      
      // Age filter
      if (dog.age < _filterOptions.minAge || dog.age > _filterOptions.maxAge) return false;
      
      // Size filter
      if (_filterOptions.sizes.isNotEmpty && !_filterOptions.sizes.contains(dog.size)) return false;
      
      // Gender filter
      if (_filterOptions.genders.isNotEmpty && !_filterOptions.genders.contains(dog.gender)) return false;
      
      // Breed filter
      if (_filterOptions.breeds.isNotEmpty && !_filterOptions.breeds.contains(dog.breed)) return false;
      
      return true;
    }).toList();
  }

  Future<void> _loadNearbyDogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = SupabaseAuth.currentUser;
      if (user == null) {
        // If not logged in, show sample data
        setState(() {
          _nearbyDogs = SampleData.nearbyDogs;
          _isLoading = false;
        });
        return;
      }

      // Get real nearby dogs from database! 🎉
      final dogData = await BarkDateMatchService.getNearbyDogs(user.id);
      
      // Convert database data to Dog objects
      final List<Dog> dogs = dogData.map<Dog>((data) {
        final userData = data['users'] as Map<String, dynamic>?;
        return Dog(
          id: data['id'] as String,
          name: data['name'] as String,
          breed: data['breed'] as String,
          age: data['age'] as int,
          size: data['size'] as String,
          gender: data['gender'] as String,
          bio: data['bio'] as String? ?? '',
          photos: List<String>.from(data['photo_urls'] ?? []),
          ownerId: (data['user_id'] ?? userData?['id'] ?? '') as String,
          ownerName: userData?['name'] as String? ?? 'Unknown Owner',
          distanceKm: 2.5, // TODO: Calculate real distance based on location
        );
      }).toList();

      setState(() {
        _nearbyDogs = dogs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading nearby dogs: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Fallback to sample data
        _nearbyDogs = SampleData.nearbyDogs;
      });
    }
  }

  Future<void> _refreshFeed() async {
    setState(() => _isRefreshing = true);
    
    // Reload fresh data from database! 🔄
    await Future.wait([
      _loadNearbyDogs(),
      _loadDashboardData(),
    ]);
    
    setState(() => _isRefreshing = false);
  }

  Future<void> _loadDashboardData() async {
    try {
      final user = SupabaseAuth.currentUser;
      if (user == null) {
        setState(() {
          _upcomingPlaydates = 3;
          _unreadNotifications = 5;
          _mutualBarks = 2;
        });
        return;
      }

      // Load real counts from database
      final results = await Future.wait([
        _getUpcomingPlaydatesCount(user.id),
        notif_service.NotificationService.getUnreadCount(user.id),
        _getMutualBarksCount(user.id),
      ]);

      if (mounted) {
        setState(() {
          _upcomingPlaydates = results[0] as int;
          _unreadNotifications = results[1] as int;
          _mutualBarks = results[2] as int;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  Future<void> _loadCheckInStatus() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted) {
        setState(() {
          _hasActiveCheckIn = checkIn != null;
        });
      }
    } catch (e) {
      debugPrint('Error loading check-in status: $e');
    }
  }

  Future<void> _loadFeedSections() async {
    try {
      final user = SupabaseAuth.currentUser;
      if (user == null) {
        _loadSampleFeedData();
        return;
      }

      // Prepare variables to collect data
      List<Map<String, dynamic>> playdates = [];
      List<Event> myEvents = [];
      List<Event> suggestedEvents = [];
      List<Map<String, dynamic>> friends = [];

      // Check cache first for quick initial display
      final cachedPlaydates = CacheService().getCachedPlaydateList(user.id, 'upcoming');
      if (cachedPlaydates != null) {
        playdates = cachedPlaydates;
      }
      
      final cachedEvents = CacheService().getCachedEventList('suggested_${user.id}');
      if (cachedEvents != null) {
        suggestedEvents = cachedEvents.cast<Event>();
      }

      final cachedFriends = CacheService().getCachedFriendList('user_${user.id}');
      if (cachedFriends != null) {
        friends = cachedFriends;
      }

      // Load fresh data in background
      String? myDogId;
      try {
        final userDogs = await BarkDateUserService.getUserDogs(user.id);
        if (userDogs.isNotEmpty) {
          myDogId = userDogs.first['id'] as String?;
        }
      } catch (_) {}

      // Parallel fetch all sections
      final results = await Future.wait([
        PlaydateQueryService.getUserPlaydatesAggregated(user.id)
            .catchError((e) {
          debugPrint('Error loading playdates: $e');
          return {'upcoming': <Map<String, dynamic>>[]};
        }),
        EventService.getUserParticipatingEvents(user.id)
            .catchError((e) {
          debugPrint('Error loading my events: $e');
          return <Event>[];
        }),
        (myDogId != null 
            ? EventService.getRecommendedEvents(dogId: myDogId!, dogAge: '3', dogSize: 'medium')
            : EventService.getUpcomingEvents(limit: 8))
            .catchError((e) {
          debugPrint('Error loading suggested events: $e');
          return <Event>[];
        }),
        (myDogId != null 
            ? DogFriendshipService.getDogFriends(myDogId!)
            : Future.value(<Map<String, dynamic>>[]))
            .catchError((e) {
          debugPrint('Error loading friends: $e');
          return <Map<String, dynamic>>[];
        }),
      ]);

      // Update cache with fresh data
      playdates = (results[0] as Map)['upcoming'] as List<Map<String, dynamic>>? ?? [];
      CacheService().cachePlaydateList(user.id, 'upcoming', playdates);
      
      myEvents = results[1] as List<Event>;
      
      suggestedEvents = results[2] as List<Event>;
      CacheService().cacheEventList('suggested_${user.id}', suggestedEvents);

      friends = results[3] as List<Map<String, dynamic>>;
      if (myDogId != null && friends.isNotEmpty) {
        CacheService().cacheFriendList('user_${user.id}', friends);
      }

      // Single setState to update ALL sections at once
      if (mounted) {
        setState(() {
          _upcomingFeedPlaydates = playdates;
          _myEvents = myEvents;
          _suggestedEvents = suggestedEvents;
          _friendDogs = friends;
        });
      }

      // If all lists are empty, show sample data
      if (_upcomingFeedPlaydates.isEmpty && _myEvents.isEmpty && _suggestedEvents.isEmpty && _friendDogs.isEmpty) {
        _loadSampleFeedData();
      }
    } catch (e) {
      debugPrint('Error loading feed sections: $e');
      _loadSampleFeedData();
    }
  }

  void _loadSampleFeedData() {
    final now = DateTime.now();
    
    setState(() {
      // Sample upcoming playdates
      _upcomingFeedPlaydates = [
        {
          'id': 'sample-pd-1',
          'title': 'Morning Walk at Central Park',
          'location': 'Central Park Dog Run',
          'scheduled_at': now.add(const Duration(days: 1, hours: 10)).toIso8601String(),
        },
        {
          'id': 'sample-pd-2',
          'title': 'Beach Playdate',
          'location': 'Crissy Field Beach',
          'scheduled_at': now.add(const Duration(days: 3, hours: 14)).toIso8601String(),
        },
      ];

      // Sample suggested events
      _suggestedEvents = [
        Event(
          id: 'sample-event-1',
          title: 'Puppy Social Hour',
          description: 'Fun social time for puppies under 1 year',
          organizerId: 'org-1',
          organizerType: 'user',
          organizerName: 'Sarah Johnson',
          organizerAvatarUrl: '',
          startTime: now.add(const Duration(days: 5, hours: 16)),
          endTime: now.add(const Duration(days: 5, hours: 18)),
          location: 'Golden Gate Park',
          category: 'social',
          maxParticipants: 15,
          currentParticipants: 8,
          targetAgeGroups: ['puppy'],
          targetSizes: ['small', 'medium'],
          price: 0,
          photoUrls: [],
          requiresRegistration: true,
          status: 'upcoming',
          createdAt: now,
          updatedAt: now,
        ),
        Event(
          id: 'sample-event-2',
          title: 'Training Workshop',
          description: 'Basic obedience training',
          organizerId: 'org-2',
          organizerType: 'professional',
          organizerName: 'K9 Training Center',
          organizerAvatarUrl: '',
          startTime: now.add(const Duration(days: 7, hours: 10)),
          endTime: now.add(const Duration(days: 7, hours: 12)),
          location: 'Training Center',
          category: 'training',
          maxParticipants: 10,
          currentParticipants: 6,
          targetAgeGroups: ['adult'],
          targetSizes: ['small', 'medium', 'large'],
          price: 45.0,
          photoUrls: [],
          requiresRegistration: true,
          status: 'upcoming',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Sample friends
      _friendDogs = [
        {
          'friend_dog': {
            'id': 'friend-1',
            'name': 'Max',
            'main_photo_url': '',
          },
        },
        {
          'friend_dog': {
            'id': 'friend-2',
            'name': 'Luna',
            'main_photo_url': '',
          },
        },
        {
          'friend_dog': {
            'id': 'friend-3',
            'name': 'Charlie',
            'main_photo_url': '',
          },
        },
      ];
    });
  }

  Future<int> _getUpcomingPlaydatesCount(String userId) async {
    try {
      final now = DateTime.now();
      final data = await SupabaseConfig.client
          .from('playdates')
          .select('id')
          .or('organizer_id.eq.$userId,participant_id.eq.$userId')
          .eq('status', 'confirmed')
          .gte('scheduled_at', now.toIso8601String());
      return data.length;
    } catch (e) {
      debugPrint('Error getting playdate count: $e');
      return 0;
    }
  }

  Future<int> _getMutualBarksCount(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('matches')
          .select('id')
          .eq('user_id', userId)
          .eq('is_mutual', true)
          .eq('action', 'bark');
      return data.length;
    } catch (e) {
      debugPrint('Error getting mutual barks count: $e');
      return 0;
    }
  }

  void _setupRealtimeSubscriptions() {
    final user = SupabaseAuth.currentUser;
    if (user == null) return;

    // Subscribe to notifications
    SupabaseConfig.client
        .channel('notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _unreadNotifications++;
              });
              // Show snackbar for new notification
              final data = payload.newRecord;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['title'] as String? ?? 'New notification'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                ),
              );
            }
          },
        )
        .subscribe();

    // Subscribe to playdates
    SupabaseConfig.client
        .channel('playdates_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playdates',
          callback: (payload) {
            if (mounted) {
              _loadDashboardData();
            }
          },
        )
        .subscribe();

    // Subscribe to matches (barks)
    SupabaseConfig.client
        .channel('matches_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              _loadDashboardData();
              if (payload.eventType == PostgresChangeEvent.insert) {
                final data = payload.newRecord;
                if (data['is_mutual'] == true) {
                  setState(() {
                    _mutualBarks++;
                  });
                }
              }
            }
          },
        )
        .subscribe();
  }

  void _cancelSubscriptions() {
    final user = SupabaseAuth.currentUser;
    if (user != null) {
      SupabaseConfig.client.channel('notifications_${user.id}').unsubscribe();
      SupabaseConfig.client.channel('playdates_${user.id}').unsubscribe();
      SupabaseConfig.client.channel('matches_${user.id}').unsubscribe();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        currentFilters: _filterOptions,
        onApplyFilters: (filters) {
          setState(() => _filterOptions = filters);
        },
      ),
    );
  }

  void _openDrawer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearby Friends',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: _openDrawer,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          slivers: [
            // Dashboard section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDashboard(),
              ),
            ),

            // Upcoming Playdates section
            if (_upcomingFeedPlaydates.isNotEmpty)
              SliverToBoxAdapter(child: _buildUpcomingPlaydatesSection()),

            // My Events section
            if (_myEvents.isNotEmpty)
              SliverToBoxAdapter(child: _buildEventsSection('My Events', _myEvents)),

            // Suggested Events section
            if (_suggestedEvents.isNotEmpty)
              SliverToBoxAdapter(child: _buildEventsSection('Suggested Events', _suggestedEvents)),

            // Friends section
            if (_friendDogs.isNotEmpty)
              SliverToBoxAdapter(child: _buildFriendsSection()),
            
            // Dogs list header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Dogs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_filteredDogs.length} found',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Dogs list
            _filteredDogs.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dog = _filteredDogs[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: GestureDetector(
                            onTap: () => _showDogProfile(dog),
                            child: DogCard(
                              dog: dog,
                              onBarkPressed: () => _onBarkPressed(context, dog),
                              onPlaydatePressed: () => _onPlaydatePressed(context, dog),
                            ),
                          ),
                        );
                      },
                      childCount: _filteredDogs.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBarkPressed(BuildContext context, Dog dog) async {
    try {
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to bark at dogs')),
        );
        return;
      }

      // Get current user's dog
      final userDogs = await BarkDateUserService.getUserDogs(currentUser.id);
      if (userDogs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create a dog profile first')),
        );
        return;
      }

      final myDogId = userDogs.first['id'];

      // Send bark notification
      final success = await BarkNotificationService.sendBark(
        fromUserId: currentUser.id,
        toUserId: dog.ownerId,
        fromDogId: myDogId,
        toDogId: dog.id,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Woof! I barked at ${dog.name}! 🐕'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('I already barked at ${dog.name} recently'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending bark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send bark. Please try again.')),
        );
      }
    }
  }

  Future<void> _onPlaydatePressed(BuildContext context, Dog dog) async {
    try {
      final currentUser = SupabaseConfig.auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to request playdates')),
        );
        return;
      }

      // Show playdate request modal
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PlaydateRequestModal(
          targetDog: dog,
          targetUserId: dog.ownerId,
        ),
      );

      // If playdate was successfully created, refresh the feed
      if (result == true) {
        _loadNearbyDogs();
      }
    } catch (e) {
      debugPrint('Error showing playdate modal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open playdate request. Please try again.')),
        );
      }
    }
  }

  void _showDogProfile(Dog dog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DogProfileDetail(dog: dog),
      ),
    );
  }

  Widget _buildDashboard() {
    // Use responsive height based on screen size
    final cardHeight = AppResponsive.horizontalCardHeight(
      context,
      mobile: 72, // Reduced from 80 for small screens
      tablet: 90,
      desktop: 100,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            padding: AppResponsive.screenPadding(context),
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(
              width: AppResponsive.spacing(context, mobile: 10, tablet: 12),
            ),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _buildCompactActionCard(
                    icon: Icons.calendar_today,
                    title: 'Playdates',
                    color: Colors.blue,
                    badge: _upcomingPlaydates > 0 ? _upcomingPlaydates : null,
                    onTap: () {
                      MainNavigation.switchTab(context, 3);
                      _loadDashboardData();
                    },
                  );
                case 1:
                  return _buildCompactActionCard(
                    icon: Icons.notifications,
                    title: 'Alerts',
                    color: Colors.orange,
                    badge: _unreadNotifications > 0 ? _unreadNotifications : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    ).then((_) => _loadDashboardData()),
                  );
                case 2:
                  return _buildCompactActionCard(
                    icon: _hasActiveCheckIn ? Icons.pets : Icons.location_on,
                    title: 'Check In',
                    color: _hasActiveCheckIn ? Colors.green : Colors.orange,
                    onTap: _hasActiveCheckIn ? _showCheckOutOptions : () => MainNavigation.switchTab(context, 1),
                  );
                case 3:
                  return _buildCompactActionCard(
                    icon: Icons.favorite,
                    title: 'Matches',
                    color: Colors.red,
                    badge: _mutualBarks > 0 ? _mutualBarks : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CatchScreen()),
                    ).then((_) => _loadDashboardData()),
                  );
                case 4:
                  return _buildCompactActionCard(
                    icon: Icons.photo_library,
                    title: 'Social',
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SocialFeedScreen())),
                  );
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    // Responsive sizing
    final cardWidth = AppResponsive.safeHorizontalItemWidth(
      context,
      context.isSmallMobile ? 85 : 95,
    );
    final iconSize = AppResponsive.iconSize(context, 20);
    final iconContainerSize = AppResponsive.iconSize(context, 34); // Reduced from 36
    final padding = AppResponsive.cardPadding(context);
    
    return SizedBox(
      width: cardWidth,
      child: AppCard(
        padding: EdgeInsets.all(padding.left * 0.8), // Slightly less padding
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Minimize size to prevent overflow
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          badge.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppResponsive.fontSize(context, 9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2), // Reduced spacing to prevent overflow
            Flexible( // Allow text to shrink if needed
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: AppResponsive.fontSize(context, 11),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No dogs found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or expanding your search radius.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _filterOptions = FilterOptions());
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  // ========= Airbnb-style feed sections =========

  Widget _buildUpcomingPlaydatesSection() {
    final cardWidth = AppResponsive.horizontalCardWidth(
      context,
      mobile: 240,
      tablet: 280,
    );
    final cardHeight = AppResponsive.horizontalCardHeight(
      context,
      mobile: 165,
      tablet: 190,
    );
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.screenPadding(context),
            child: const Text('Upcoming Playdates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: AppResponsive.screenPadding(context),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final pd = _upcomingFeedPlaydates[index];
                final title = (pd['title'] as String?)?.isNotEmpty == true ? pd['title'] : 'Playdate';
                final location = pd['location'] as String? ?? '';
                final dt = DateTime.tryParse(pd['scheduled_at']?.toString() ?? '');
                final dateText = dt != null ? '${dt.month}/${dt.day} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';

                return SizedBox(
                  width: cardWidth,
                  child: AppCard(
                    padding: AppResponsive.cardPadding(context),
                    onTap: () => MainNavigation.switchTab(context, 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title ?? 'Playdate',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: AppResponsive.fontSize(context, 16),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dateText,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: AppResponsive.fontSize(context, 12),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: AppResponsive.fontSize(context, 12),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        AppButton(
                          text: 'View',
                          size: AppButtonSize.small,
                          onPressed: () => MainNavigation.switchTab(context, 3),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => SizedBox(
                width: AppResponsive.spacing(context, mobile: 10, tablet: 12),
              ),
              itemCount: _upcomingFeedPlaydates.length.clamp(0, 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(String title, List<Event> events) {
    final cardWidth = AppResponsive.horizontalCardWidth(
      context,
      mobile: 260,
      tablet: 300,
    );
    final cardHeight = AppResponsive.horizontalCardHeight(
      context,
      mobile: 240,
      tablet: 260,
    );
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.screenPadding(context),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: AppResponsive.screenPadding(context),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final event = events[index];
                return SizedBox(
                  width: cardWidth,
                  child: AppCard(
                    padding: AppResponsive.cardPadding(context),
                    onTap: () => MainNavigation.switchTab(context, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: AppResponsive.fontSize(context, 16),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        // Date & time
                        Row(
                          children: [
                            Icon(Icons.schedule, size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.formattedDate,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: AppResponsive.fontSize(context, 12),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        // Location
                        Row(
                          children: [
                            Icon(Icons.location_on, size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.location,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: AppResponsive.fontSize(context, 12),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              event.isFree ? 'Free' : event.formattedPrice,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: AppResponsive.fontSize(context, 14),
                              ),
                            ),
                            AppButton(
                              text: 'Details',
                              size: AppButtonSize.small,
                              type: AppButtonType.outline,
                              onPressed: () => MainNavigation.switchTab(context, 2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => SizedBox(
                width: AppResponsive.spacing(context, mobile: 10, tablet: 12),
              ),
              itemCount: events.length.clamp(0, 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    final cardWidth = AppResponsive.horizontalCardWidth(
      context,
      mobile: 150, // tighter on small screens
      tablet: 200,
    );
    final cardHeight = AppResponsive.horizontalCardHeight(
      context,
      mobile: 120, // Increased from 96 to fit vertical buttons
      tablet: 140,  // Increased from 116
    );
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.screenPadding(context),
            child: const Text('Friends & Barks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: AppResponsive.screenPadding(context),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final friend = _friendDogs[index];
                final dog = friend['friend_dog'] ?? friend['dog'] ?? {};
                final dogName = dog['name']?.toString() ?? 'Friend';
                final photo = dog['main_photo_url']?.toString();
                
                return SizedBox(
                  width: cardWidth,
                  child: AppCard(
                    padding: EdgeInsets.all(AppResponsive.cardPadding(context).left * 0.6), // Tighter padding
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: AppResponsive.avatarRadius(context, 14), // Slightly smaller
                          backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: (photo == null || photo.isEmpty) 
                              ? Icon(Icons.pets, size: AppResponsive.iconSize(context, 14)) 
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded( // Use Expanded instead of Flexible
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dogName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppResponsive.fontSize(context, 12), // Slightly smaller
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Vertical stack to prevent horizontal overflow
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: 28, // Compact height
                                    child: AppButton(
                                      text: 'Bark',
                                      size: AppButtonSize.small,
                                      onPressed: () {},
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    height: 28, // Compact height
                                    child: AppButton(
                                      text: 'Invite',
                                      size: AppButtonSize.small,
                                      type: AppButtonType.outline,
                                      onPressed: () => MainNavigation.switchTab(context, 3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => SizedBox(
                width: AppResponsive.spacing(context, mobile: 10, tablet: 12),
              ),
              itemCount: _friendDogs.length.clamp(0, 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckInOptions() {
    Navigator.pushNamed(context, '/map');
  }

  void _showCheckOutOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check Out'),
        content: const Text('Are you ready to leave the park?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await CheckInService.checkOut();
              if (success && mounted) {
                setState(() {
                  _hasActiveCheckIn = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checked out successfully! See you next time! 🐾'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
  }
}