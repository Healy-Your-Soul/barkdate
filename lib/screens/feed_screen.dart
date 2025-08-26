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

  @override
  void initState() {
    super.initState();
    _loadNearbyDogs();
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
      final dogs = dogData.map((data) {
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
    await _loadNearbyDogs();
    
    setState(() => _isRefreshing = false);
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

  void _onBarkPressed(BuildContext context, Dog dog) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You barked at ${dog.name}! 🐕'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
              subtitle: '3 upcoming',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaydatesScreen()),
              ),
            ),
            _buildDashboardCard(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: '5 new',
              color: Colors.orange,
              badge: 5,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              ),
            ),
            _buildDashboardCard(
              icon: Icons.favorite,
              title: 'Catch',
              subtitle: 'Find new friends',
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CatchScreen()),
              ),
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