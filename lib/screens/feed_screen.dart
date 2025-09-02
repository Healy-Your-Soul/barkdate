import 'package:flutter/material.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/widgets/dog_card.dart';
import 'package:barkdate/widgets/filter_sheet.dart';
import 'package:barkdate/screens/catch_screen.dart';
import 'package:barkdate/screens/notifications_screen.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/social_feed_screen.dart';
import 'package:barkdate/screens/dog_profile_detail.dart';
import 'package:barkdate/screens/settings_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/widgets/playdate_request_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/notification_service.dart' as notif_service;

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

  @override
  void initState() {
    super.initState();
    _loadNearbyDogs();
    _loadDashboardData();
    _setupRealtimeSubscriptions();
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
              content: Text('You barked at ${dog.name}! 🐕'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already barked at ${dog.name} recently'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildDashboardCard(
              icon: Icons.calendar_today,
              title: 'Playdates',
              subtitle: _upcomingPlaydates > 0 
                  ? '$_upcomingPlaydates upcoming' 
                  : 'Schedule one',
              color: Colors.blue,
              badge: _upcomingPlaydates > 0 ? _upcomingPlaydates : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaydatesScreen()),
              ).then((_) => _loadDashboardData()),
            ),
            _buildDashboardCard(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: _unreadNotifications > 0 
                  ? '$_unreadNotifications new' 
                  : 'All caught up',
              color: Colors.orange,
              badge: _unreadNotifications > 0 ? _unreadNotifications : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ).then((_) => _loadDashboardData()),
            ),
            _buildDashboardCard(
              icon: Icons.favorite,
              title: 'Matches',
              subtitle: _mutualBarks > 0 
                  ? '$_mutualBarks mutual barks' 
                  : 'Find new friends',
              color: Colors.red,
              badge: _mutualBarks > 0 ? _mutualBarks : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CatchScreen()),
              ).then((_) => _loadDashboardData()),
            ),
            _buildDashboardCard(
              icon: Icons.photo_library,
              title: 'Social',
              subtitle: 'Community posts',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SocialFeedScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
}