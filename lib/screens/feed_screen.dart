import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/widgets/dog_card.dart';
import 'package:barkdate/widgets/filter_sheet.dart';
import 'package:barkdate/screens/catch_screen.dart';
import 'package:barkdate/screens/notifications_screen.dart';
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
import 'package:barkdate/widgets/dog_loading_widget.dart';
// Events feature
import 'package:barkdate/services/event_service.dart';
import 'package:barkdate/models/event.dart';
// Cache service
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/services/feed_service.dart';
import 'package:barkdate/services/feed_filter_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Static flag to prevent multiple FeedScreen instances from loading simultaneously
  static bool _isGloballyLoading = false;

  FilterOptions _filterOptions = FilterOptions();
  bool _isRefreshing = false;
  // ignore: unused_field
  bool _isLoading = true;
  bool _isInitialLoading = false;
  bool _hasLoadedOnce = false; // Prevent double loading
  List<Dog> _nearbyDogs = [];
  // ignore: unused_field
  String? _error;
  int _upcomingPlaydates = 0;
  int _unreadNotifications = 0;
  int _mutualBarks = 0;
  bool _hasActiveCheckIn = false;
  List<Map<String, dynamic>> _upcomingFeedPlaydates = [];
  List<Event> _myEvents = [];
  List<Event> _suggestedEvents = [];
  List<Map<String, dynamic>> _friendDogs = [];
  String? _myPrimaryDogId;
  // ignore: unused_field
  Map<String, dynamic> _feedMeta = {};
  final ScrollController _scrollController = ScrollController();

  // Pagination state
  static const int _dogsPageSize = 20;
  static const int _playdatesPageSize = 20;
  static const int _eventsPageSize = 20;
  static const int _friendsPageSize = 20;

  int _nearbyDogsPage = 0;
  bool _hasMoreNearbyDogs = true;
  bool _isLoadingMoreDogs = false;

  int _playdatesPage = 0;
  bool _hasMorePlaydates = true;
  bool _isLoadingMorePlaydates = false;

  int _myEventsPage = 0;
  bool _hasMoreMyEvents = true;
  bool _isLoadingMoreMyEvents = false;

  int _suggestedEventsPage = 0;
  bool _hasMoreSuggestedEvents = true;
  bool _isLoadingMoreSuggestedEvents = false;

  int _friendsPage = 0;
  bool _hasMoreFriends = true;
  bool _isLoadingMoreFriends = false;

  void _handleScrollPagination() {
    if (!_hasMoreNearbyDogs || _isLoadingMoreDogs || _isRefreshing) {
      return;
    }

    if (!_scrollController.hasClients) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      _loadMoreNearbyDogs();
    }
  }

  @override
  void initState() {
    super.initState();
    _isInitialLoading = true;
    _scrollController.addListener(_handleScrollPagination);
    // Hydrate UI immediately from cache (if any), then refresh in background
    setState(() {
      _hydrateFromCache();
    });
    _loadAllFeedData().then((_) {
      _hasLoadedOnce = true; // Mark as loaded to prevent double loading
      _setupRealtimeSubscriptions();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollPagination);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't automatically refresh on every rebuild - user can pull-to-refresh manually
    // This prevents unnecessary API calls when the widget rebuilds for other reasons
  }

  List<Dog> get _filteredDogs {
    return _nearbyDogs.where((dog) {
      // Distance filter
      if (dog.distanceKm > _filterOptions.maxDistance) return false;

      // Age filter
      if (dog.age < _filterOptions.minAge || dog.age > _filterOptions.maxAge) {
        return false;
      }

      // Size filter
      if (_filterOptions.sizes.isNotEmpty &&
          !_filterOptions.sizes.contains(dog.size)) {
        return false;
      }

      // Gender filter
      if (_filterOptions.genders.isNotEmpty &&
          !_filterOptions.genders.contains(dog.gender)) {
        return false;
      }

      // Breed filter
      if (_filterOptions.breeds.isNotEmpty &&
          !_filterOptions.breeds.contains(dog.breed)) {
        return false;
      }

      return true;
    }).toList();
  }

  Dog _mapDogFromRaw(Map<String, dynamic> data) {
    final userData = data['users'] as Map<String, dynamic>?;
    final photosRaw =
        data['photo_urls'] ?? data['photos'] ?? data['photoUrls'] ?? [];
    final ownerNameValue =
        data['owner_name'] ?? userData?['name'] ?? 'Unknown Owner';
    final ownerIdValue = data['user_id'] ?? userData?['id'] ?? '';
    final distance = (data['distance_km'] ?? data['distanceKm']) as num?;

    return Dog(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Doggo',
      breed: data['breed'] as String? ?? 'Mixed',
      age: (data['age'] as num?)?.toInt() ?? 0,
      size: data['size'] as String? ?? 'medium',
      gender: data['gender'] as String? ?? 'unknown',
      bio: data['bio'] as String? ?? '',
      photos: ((photosRaw as List?) ?? [])
          .whereType<dynamic>()
          .map((e) => e.toString())
          .toList(),
      ownerId: ownerIdValue.toString(),
      ownerName: ownerNameValue.toString(),
      distanceKm: distance?.toDouble() ?? 0.0,
    );
  }

  Future<void> _loadNearbyDogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final user = SupabaseAuth.currentUser;
      if (user == null) {
        setState(() {
          _nearbyDogs = SampleData.nearbyDogs;
          _hasMoreNearbyDogs = false;
          _isLoading = false;
        });
        return;
      }

      final dogData = await BarkDateMatchService.getNearbyDogs(
        user.id,
        limit: _dogsPageSize,
        offset: 0,
      );

      final dogs = dogData.map(_mapDogFromRaw).toList();

      setState(() {
        _nearbyDogs = dogs;
        _nearbyDogsPage = 0;
        _hasMoreNearbyDogs = dogData.length >= _dogsPageSize;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading nearby dogs: $e');
      setState(() {
        _error = e.toString();
        _nearbyDogs = [];
        _hasMoreNearbyDogs = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNearbyDogs() async {
    final user = SupabaseAuth.currentUser;
    if (user == null || !_hasMoreNearbyDogs || _isLoadingMoreDogs) {
      return;
    }

    setState(() {
      _isLoadingMoreDogs = true;
    });

    try {
      final nextPage = _nearbyDogsPage + 1;
      final offset = nextPage * _dogsPageSize;
      final dogData = await BarkDateMatchService.getNearbyDogs(
        user.id,
        limit: _dogsPageSize,
        offset: offset,
      );

      final dogs = dogData.map(_mapDogFromRaw).toList();

      setState(() {
        _nearbyDogs.addAll(dogs);
        _nearbyDogsPage = nextPage;
        _hasMoreNearbyDogs = dogData.length >= _dogsPageSize;
        _isLoadingMoreDogs = false;
      });
    } catch (e) {
      debugPrint('Error loading more nearby dogs: $e');
      setState(() {
        _isLoadingMoreDogs = false;
        _hasMoreNearbyDogs = false;
      });
    }
  }

  Future<void> _loadMorePlaydates() async {
    final user = SupabaseAuth.currentUser;
    if (user == null || !_hasMorePlaydates || _isLoadingMorePlaydates) {
      return;
    }

    setState(() {
      _isLoadingMorePlaydates = true;
    });

    try {
      final nextPage = _playdatesPage + 1;
      final offset = nextPage * _playdatesPageSize;
      final data = await PlaydateQueryService.getUserPlaydatesAggregated(
        user.id,
        upcomingLimit: _playdatesPageSize,
        upcomingOffset: offset,
      );
      final upcoming =
          (data['upcoming'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      setState(() {
        _upcomingFeedPlaydates.addAll(upcoming);
        _playdatesPage = nextPage;
        _hasMorePlaydates = upcoming.length >= _playdatesPageSize;
        _isLoadingMorePlaydates = false;
      });

      if (upcoming.isNotEmpty) {
        CacheService()
            .cachePlaydateList(user.id, 'upcoming', _upcomingFeedPlaydates);
      }
    } catch (e) {
      debugPrint('Error loading more playdates: $e');
      setState(() {
        _isLoadingMorePlaydates = false;
        _hasMorePlaydates = false;
      });
    }
  }

  Future<void> _loadMoreMyEvents() async {
    final user = SupabaseAuth.currentUser;
    if (user == null || !_hasMoreMyEvents || _isLoadingMoreMyEvents) {
      return;
    }

    setState(() {
      _isLoadingMoreMyEvents = true;
    });

    try {
      final nextPage = _myEventsPage + 1;
      final offset = nextPage * _eventsPageSize;
      final events = await EventService.getUserParticipatingEvents(
        user.id,
        limit: _eventsPageSize,
        offset: offset,
      );

      setState(() {
        _myEvents.addAll(events);
        _myEventsPage = nextPage;
        _hasMoreMyEvents = events.length >= _eventsPageSize;
        _isLoadingMoreMyEvents = false;
      });
    } catch (e) {
      debugPrint('Error loading more my events: $e');
      setState(() {
        _isLoadingMoreMyEvents = false;
        _hasMoreMyEvents = false;
      });
    }
  }

  Future<void> _loadMoreSuggestedEvents() async {
    if (!_hasMoreSuggestedEvents || _isLoadingMoreSuggestedEvents) {
      return;
    }

    setState(() {
      _isLoadingMoreSuggestedEvents = true;
    });

    try {
      final nextPage = _suggestedEventsPage + 1;
      final offset = nextPage * _eventsPageSize;
      final events = await EventService.getUpcomingEvents(
        limit: _eventsPageSize,
        offset: offset,
      );

      setState(() {
        _suggestedEvents.addAll(events);
        _suggestedEventsPage = nextPage;
        _hasMoreSuggestedEvents = events.length >= _eventsPageSize;
        _isLoadingMoreSuggestedEvents = false;
      });

      final user = SupabaseAuth.currentUser;
      if (user != null && events.isNotEmpty) {
        CacheService().cacheEventList('suggested_${user.id}', _suggestedEvents);
      }
    } catch (e) {
      debugPrint('Error loading more suggested events: $e');
      setState(() {
        _isLoadingMoreSuggestedEvents = false;
        _hasMoreSuggestedEvents = false;
      });
    }
  }

  Future<void> _loadMoreFriends() async {
    final dogId = _myPrimaryDogId;
    if (dogId == null || !_hasMoreFriends || _isLoadingMoreFriends) {
      return;
    }

    setState(() {
      _isLoadingMoreFriends = true;
    });

    try {
      final nextPage = _friendsPage + 1;
      final offset = nextPage * _friendsPageSize;
      final friends = await DogFriendshipService.getDogFriends(
        dogId,
        limit: _friendsPageSize,
        offset: offset,
      );

      setState(() {
        _friendDogs.addAll(friends);
        _friendsPage = nextPage;
        _hasMoreFriends = friends.length >= _friendsPageSize;
        _isLoadingMoreFriends = false;
      });

      final user = SupabaseAuth.currentUser;
      if (user != null && friends.isNotEmpty) {
        CacheService().cacheFriendList('user_${user.id}', _friendDogs);
      }
    } catch (e) {
      debugPrint('Error loading more friends: $e');
      setState(() {
        _isLoadingMoreFriends = false;
        _hasMoreFriends = false;
      });
    }
  }

  Future<void> _refreshFeed() async {
    setState(() => _isRefreshing = true);
    // Allow refresh even after first load
    final wasLoadedOnce = _hasLoadedOnce;
    _hasLoadedOnce = false; // Temporarily allow loading
    await _loadAllFeedData();
    _hasLoadedOnce = wasLoadedOnce; // Restore state
    setState(() => _isRefreshing = false);
  }

  void _applyFeedSnapshot(
    Map<String, dynamic> snapshot, {
    bool fromCache = false,
  }) {
    final counters = Map<String, dynamic>.from(
      (snapshot['counters'] as Map?) ?? const {},
    );
    final meta = Map<String, dynamic>.from(
      (snapshot['meta'] as Map?) ?? const {},
    );
    final checkin = Map<String, dynamic>.from(
      (snapshot['checkin'] as Map?) ?? const {},
    );

    final nearbyRaw = (snapshot['nearby_dogs'] as List?) ?? const [];
    final playdatesRaw = (snapshot['upcoming_playdates'] as List?) ?? const [];
    final myEventsRaw = (snapshot['my_events'] as List?) ?? const [];
    final suggestedRaw = (snapshot['suggested_events'] as List?) ?? const [];
    final friendsRaw = (snapshot['friends'] as List?) ?? const [];

    List<Dog> nearbyDogs = nearbyRaw
        .whereType<Map>()
        .map((data) => _mapDogFromRaw(Map<String, dynamic>.from(data)))
        .toList();

    final playdates = playdatesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final myEvents = myEventsRaw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      map['organizer_type'] = map['organizer_type'] ?? 'user';
      return Event.fromJson(map);
    }).toList();

    final suggestedEvents = suggestedRaw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      map['organizer_type'] = map['organizer_type'] ?? 'user';
      return Event.fromJson(map);
    }).toList();

    final friends = friendsRaw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final friendDog = map['friend_dog'];
      if (friendDog is Map) {
        map['friend_dog'] = Map<String, dynamic>.from(friendDog);
      }
      return map;
    }).toList();

    nearbyDogs = FeedFilterService.applyFeedFilters(
      nearbyDogs: nearbyDogs,
      dogsWithEvents: meta['event_dog_ids'] as Iterable?,
      dogsWithPlaydates: meta['playdate_dog_ids'] as Iterable?,
    );

    final hasMoreNearby = nearbyRaw.length >= _dogsPageSize;
    final hasMorePlaydates = playdatesRaw.length >= _playdatesPageSize;
    final hasMoreMyEvents = myEventsRaw.length >= _eventsPageSize;
    final hasMoreSuggested = suggestedRaw.length >= _eventsPageSize;
    final hasMoreFriends = friendsRaw.length >= _friendsPageSize;

    if (mounted) {
      setState(() {
        _nearbyDogs = nearbyDogs;
        _upcomingFeedPlaydates = playdates;
        _myEvents = myEvents;
        _suggestedEvents = suggestedEvents;
        _friendDogs = friends;
        _feedMeta = meta;

        _hasMoreNearbyDogs = hasMoreNearby;
        _hasMorePlaydates = hasMorePlaydates;
        _hasMoreMyEvents = hasMoreMyEvents;
        _hasMoreSuggestedEvents = hasMoreSuggested;
        _hasMoreFriends = hasMoreFriends;

        _nearbyDogsPage = 0;
        _playdatesPage = 0;
        _myEventsPage = 0;
        _suggestedEventsPage = 0;
        _friendsPage = 0;

        _upcomingPlaydates =
            (counters['upcoming_playdates'] as num?)?.toInt() ??
                _upcomingPlaydates;
        _unreadNotifications =
            (counters['unread_notifications'] as num?)?.toInt() ??
                _unreadNotifications;
        _mutualBarks =
            (counters['mutual_barks'] as num?)?.toInt() ?? _mutualBarks;
        _hasActiveCheckIn = checkin['has_active'] == true;
        _myPrimaryDogId =
            snapshot['primary_dog_id']?.toString() ?? _myPrimaryDogId;

        if (fromCache) {
          _isInitialLoading = false;
        } else {
          _isInitialLoading = false;
          _isLoading = false;
        }
      });
    }
  }

  // Unified, batched loader to prevent staged UI updates
  Future<void> _loadAllFeedData() async {
    // Prevent double loading - only load once per session
    if (_hasLoadedOnce) {
      debugPrint('WARNING: Skipping double load - already loaded once');
      return;
    }

    // Prevent multiple FeedScreen instances from loading simultaneously
    if (_isGloballyLoading) {
      debugPrint('WARNING: Skipping load - already in progress');
      return;
    }

    _isGloballyLoading = true;

    try {
      final user = SupabaseAuth.currentUser;
      if (user == null) {
        _loadSampleFeedData();
        if (mounted) {
          setState(() {
            _nearbyDogs = SampleData.nearbyDogs;
            _isInitialLoading = false;
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      debugPrint('Fetching feed snapshot for ${user.id}');
      final snapshot = await FeedService.refreshFeedSnapshot(user.id);

      if (snapshot.isEmpty) {
        debugPrint('WARNING: Feed snapshot returned empty payload');
        if (mounted) {
          setState(() {
            _isInitialLoading = false;
            _isLoading = false;
          });
        }
      } else {
        _applyFeedSnapshot(snapshot);
        _hasLoadedOnce = true;
      }
    } catch (e) {
      debugPrint('Error in _loadAllFeedData: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialLoading = false;
          _isLoading = false;
        });
      }
    } finally {
      _isGloballyLoading = false; // Reset global flag
    }
  }

  // ===== Cache-first helpers =====
  bool get _hasAnyData =>
      _nearbyDogs.isNotEmpty ||
      _upcomingFeedPlaydates.isNotEmpty ||
      _myEvents.isNotEmpty ||
      _suggestedEvents.isNotEmpty ||
      _friendDogs.isNotEmpty;

  void _hydrateFromCache() {
    final user = SupabaseAuth.currentUser;
    if (user == null) return;

    final cachedSnapshot = CacheService().getCachedFeedSnapshot(user.id);
    if (cachedSnapshot != null && cachedSnapshot.isNotEmpty) {
      _applyFeedSnapshot(Map<String, dynamic>.from(cachedSnapshot),
          fromCache: true);
      return;
    }

    final cachedNearbyRaw = CacheService().getCachedNearbyDogs(user.id);
    if (cachedNearbyRaw != null && cachedNearbyRaw.isNotEmpty) {
      _nearbyDogs = cachedNearbyRaw.map(_mapDogFromRaw).toList();
      _nearbyDogsPage = 0;
      _hasMoreNearbyDogs = cachedNearbyRaw.length >= _dogsPageSize;
    }

    final pd = CacheService().getCachedPlaydateList(user.id, 'upcoming');
    if (pd != null) {
      _upcomingFeedPlaydates = pd;
      _playdatesPage = 0;
      _hasMorePlaydates = pd.length >= _playdatesPageSize;
    }

    final se = CacheService().getCachedEventList('suggested_${user.id}');
    if (se != null) {
      _suggestedEvents = se.cast<Event>();
      _suggestedEventsPage = 0;
      _hasMoreSuggestedEvents = se.length >= _eventsPageSize;
    }

    final fr = CacheService().getCachedFriendList('user_${user.id}');
    if (fr != null) {
      _friendDogs = fr;
      _friendsPage = 0;
      _hasMoreFriends = fr.length >= _friendsPageSize;
    }
  }

  Widget _buildFeedSkeleton() {
    return ListView(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: 20, width: 140, color: Colors.white10),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (_, __) => Container(
              width: 90,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12)),
            ),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: 5,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: 20, width: 180, color: Colors.white10),
        ),
        const SizedBox(height: 12),
        ...List.generate(
            4,
            (_) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12)),
                  ),
                )),
      ],
    );
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
          _upcomingPlaydates = results[0];
          _unreadNotifications = results[1];
          _mutualBarks = results[2];
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  void _loadSampleFeedData() {
    final now = DateTime.now();

    setState(() {
      _hasMoreNearbyDogs = false;
      _hasMorePlaydates = false;
      _hasMoreMyEvents = false;
      _hasMoreSuggestedEvents = false;
      _hasMoreFriends = false;
      _nearbyDogsPage = 0;
      _playdatesPage = 0;
      _myEventsPage = 0;
      _suggestedEventsPage = 0;
      _friendsPage = 0;
      _myPrimaryDogId = null;
      // Sample upcoming playdates
      _upcomingFeedPlaydates = [
        {
          'id': 'sample-pd-1',
          'title': 'Morning Walk at Central Park',
          'location': 'Central Park Dog Run',
          'scheduled_at':
              now.add(const Duration(days: 1, hours: 10)).toIso8601String(),
        },
        {
          'id': 'sample-pd-2',
          'title': 'Beach Playdate',
          'location': 'Crissy Field Beach',
          'scheduled_at':
              now.add(const Duration(days: 3, hours: 14)).toIso8601String(),
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
          visibility: 'public',
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
          visibility: 'public',
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationsScreen()),
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

  /// Build a distance filter chip
  Widget _buildDistanceChip(String label, double maxKm) {
    final isSelected = _filterOptions.maxDistance == maxKm;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filterOptions = _filterOptions.copyWith(maxDistance: maxKm);
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show skeleton on true first load (no cache available yet)
    if (_isInitialLoading && !_hasAnyData) {
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
        ),
        body: _buildFeedSkeleton(),
      );
    }

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
              MaterialPageRoute(
                  builder: (context) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: CustomScrollView(
          controller: _scrollController,
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
              SliverToBoxAdapter(
                child: _buildEventsSection(
                  'My Events',
                  _myEvents,
                  hasMore: _hasMoreMyEvents,
                  isLoading: _isLoadingMoreMyEvents,
                  onLoadMore: _loadMoreMyEvents,
                ),
              ),

            // Suggested Events section
            if (_suggestedEvents.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildEventsSection(
                  'Suggested Events',
                  _suggestedEvents,
                  hasMore: _hasMoreSuggestedEvents,
                  isLoading: _isLoadingMoreSuggestedEvents,
                  onLoadMore: _loadMoreSuggestedEvents,
                ),
              ),

            // Friends section
            if (_friendDogs.isNotEmpty)
              SliverToBoxAdapter(child: _buildFriendsSection()),

            // Distance filter chips - quick access
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildDistanceChip('Within 2km', 2.0),
                    _buildDistanceChip('Within 5km', 5.0),
                    _buildDistanceChip('Within 10km', 10.0),
                    _buildDistanceChip('All', 100.0),
                  ],
                ),
              ),
            ),

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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // Dogs list
            if (_filteredDogs.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else ...[
              SliverList(
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
                          onPlaydatePressed: () =>
                              _onPlaydatePressed(context, dog),
                        ),
                      ),
                    );
                  },
                  childCount: _filteredDogs.length,
                ),
              ),
              SliverToBoxAdapter(child: _buildDogsLoadMoreIndicator()),
            ],
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please create a dog profile first')),
          );
        }
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

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Woof! I barked at ${dog.name}! 🐕'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('I already barked at ${dog.name} recently'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending bark: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to send bark. Please try again.')),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to open playdate request. Please try again.')),
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
                    badge:
                        _unreadNotifications > 0 ? _unreadNotifications : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()),
                    ).then((_) => _loadDashboardData()),
                  );
                case 2:
                  return _buildCompactActionCard(
                    icon: _hasActiveCheckIn ? Icons.pets : Icons.location_on,
                    title: 'Check In',
                    color: _hasActiveCheckIn ? Colors.green : Colors.orange,
                    onTap: _hasActiveCheckIn
                        ? _showCheckOutOptions
                        : () => MainNavigation.switchTab(context, 1),
                  );
                case 3:
                  return _buildCompactActionCard(
                    icon: Icons.favorite,
                    title: 'Matches',
                    color: Colors.red,
                    badge: _mutualBarks > 0 ? _mutualBarks : null,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CatchScreen()),
                    ).then((_) => _loadDashboardData()),
                  );
                case 4:
                  return _buildCompactActionCard(
                    icon: Icons.photo_library,
                    title: 'Social',
                    color: Colors.green,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SocialFeedScreen())),
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
    final iconContainerSize =
        AppResponsive.iconSize(context, 34); // Reduced from 36
    final padding = AppResponsive.cardPadding(context);

    return SizedBox(
      width: cardWidth,
      child: AppCard(
        padding: EdgeInsets.all(padding.left * 0.8), // Slightly less padding
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content
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
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
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
            Flexible(
              // Allow text to shrink if needed
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
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

  Widget _buildDogsLoadMoreIndicator() {
    if (_isLoadingMoreDogs) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: DogCircularProgress()),
      );
    }

    if (!_hasMoreNearbyDogs) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No more dogs nearby within your current radius.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: _loadMoreNearbyDogs,
          icon: const Icon(Icons.pets),
          label: const Text('Load more dogs'),
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter({
    required bool hasMore,
    required bool isLoading,
    required VoidCallback onLoadMore,
    required String label,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: DogCircularProgress()),
      );
    }

    if (!hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: OutlinedButton(
          onPressed: onLoadMore,
          child: Text(label),
        ),
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
            child: const Text('Upcoming Playdates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              padding: AppResponsive.screenPadding(context),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final pd = _upcomingFeedPlaydates[index];
                final title = (pd['title'] as String?)?.isNotEmpty == true
                    ? pd['title']
                    : 'Playdate';
                final location = pd['location'] as String? ?? '';
                final dt =
                    DateTime.tryParse(pd['scheduled_at']?.toString() ?? '');
                final dateText = dt != null
                    ? '${dt.month}/${dt.day} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                    : '';

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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: AppResponsive.fontSize(context, 16),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                dateText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize:
                                          AppResponsive.fontSize(context, 12),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.isSmallMobile ? 4 : 6),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                location,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize:
                                          AppResponsive.fontSize(context, 12),
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
          _buildLoadMoreFooter(
            hasMore: _hasMorePlaydates,
            isLoading: _isLoadingMorePlaydates,
            onLoadMore: _loadMorePlaydates,
            label: 'Load more playdates',
          ),
        ],
      ),
    );
  }

  Widget _buildEventsSection(
    String title,
    List<Event> events, {
    required bool hasMore,
    required bool isLoading,
    required VoidCallback onLoadMore,
  }) {
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
            child: Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
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
                            Icon(Icons.schedule,
                                size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.formattedDate,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize:
                                          AppResponsive.fontSize(context, 12),
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
                            Icon(Icons.location_on,
                                size: AppResponsive.iconSize(context, 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.location,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize:
                                          AppResponsive.fontSize(context, 12),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize:
                                        AppResponsive.fontSize(context, 14),
                                  ),
                            ),
                            AppButton(
                              text: 'Details',
                              size: AppButtonSize.small,
                              type: AppButtonType.outline,
                              onPressed: () =>
                                  MainNavigation.switchTab(context, 2),
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
          _buildLoadMoreFooter(
            hasMore: hasMore,
            isLoading: isLoading,
            onLoadMore: onLoadMore,
            label: 'Load more $title',
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
      tablet: 140, // Increased from 116
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppResponsive.screenPadding(context),
            child: const Text('Friends & Barks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                    padding: EdgeInsets.all(
                        AppResponsive.cardPadding(context).left *
                            0.6), // Tighter padding
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: AppResponsive.avatarRadius(
                              context, 14), // Slightly smaller
                          backgroundImage: photo != null && photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? Icon(Icons.pets,
                                  size: AppResponsive.iconSize(context, 14))
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          // Use Expanded instead of Flexible
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dogName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppResponsive.fontSize(
                                          context, 12), // Slightly smaller
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
                                      onPressed: () =>
                                          MainNavigation.switchTab(context, 3),
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
          _buildLoadMoreFooter(
            hasMore: _hasMoreFriends,
            isLoading: _isLoadingMoreFriends,
            onLoadMore: _loadMoreFriends,
            label: 'Load more friends',
          ),
        ],
      ),
    );
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
              if (success && mounted && context.mounted) {
                setState(() {
                  _hasActiveCheckIn = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Checked out successfully! See you next time! 🐾'),
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
