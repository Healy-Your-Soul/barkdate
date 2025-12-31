import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/feed/presentation/providers/feed_provider.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
import 'package:barkdate/features/events/presentation/providers/event_provider.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
import 'package:barkdate/features/feed/presentation/widgets/feed_filter_sheet.dart';
import 'package:barkdate/widgets/dog_card.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:intl/intl.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/core/presentation/widgets/cute_empty_state.dart';

class FeedFeatureScreen extends ConsumerWidget {
  const FeedFeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyDogsAsync = ref.watch(nearbyDogsProvider);
    final playdatesAsync = ref.watch(userPlaydatesProvider);
    final eventsAsync = ref.watch(nearbyEventsProvider);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyDogsProvider);
            ref.invalidate(userPlaydatesProvider);
            ref.invalidate(nearbyEventsProvider);
            ref.invalidate(userStatsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header matching Messages/Profile style
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bark',
                        style: AppTypography.brandTitle(
                          color: Theme.of(context).colorScheme.primary, // New primary color
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: () => showFeedFilterSheet(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications_none),
                            onPressed: () => context.push('/notifications'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 1. Dashboard Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildDashboard(context, userStatsAsync, playdatesAsync),
                ),
              ),

              // 1.5 Find Your Pack Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _buildPackSearchBar(context),
                ),
              ),

            // 2. Upcoming Playdates Section
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, "Upcoming Playdates", () {
                context.go('/playdates');
              }),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 156,
                child: playdatesAsync.when(
                  data: (playdates) {
                    if (playdates.isEmpty) {
                      return _buildEmptyHorizontalState(
                        context,
                        "No playdates yet",
                        Icons.calendar_today,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                      itemCount: playdates.length,
                      itemBuilder: (context, index) {
                        final playdate = playdates[index];
                        return _buildPlaydateCard(context, playdate);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 3. Suggested Events Section
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, "Suggested Events", () {
                context.go('/events');
              }),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 156,
                child: eventsAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return _buildEmptyHorizontalState(
                        context,
                        "No events nearby",
                        Icons.event,
                      );
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _buildEventCard(context, event);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // 4. Nearby Dogs Header with Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Dogs',
                          style: AppTypography.h2(),
                        ),
                        // Toggle buttons will be managed by parent
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Find playmates in your area',
                      style: AppTypography.bodyMedium().copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Friends / All Toggle
                    _NearbyDogsToggle(),
                  ],
                ),
              ),
            ),

            // 4. Nearby Dogs List
            nearbyDogsAsync.when(
              data: (dogs) {
                if (dogs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CuteEmptyState(
                        icon: Icons.location_off,
                        title: 'No Dogs Nearby',
                        message: 'We couldn\'t find any dogs in your area. Try adjusting your filters or check back later!',
                        actionLabel: 'Adjust Filters',
                        onAction: () {
                          // TODO: Open filters
                        },
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dog = dogs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: AppSpacing.xs,
                        ),
                        child: DogCard(
                          dog: dog,
                          onTap: () {
                            context.push('/dog-details', extra: dog);
                          },
                          onBarkPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You barked at ${dog.name}! 🐕'),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onPlaydatePressed: () {
                            context.push('/create-playdate', extra: dog);
                          },
                        ),
                      );
                    },
                    childCount: dogs.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Error: $error'),
                  ),
                ),
              ),
              ),
            
            // 5. Sniff Around (Social Feed Preview)
            const SliverToBoxAdapter(child: SizedBox(height: 32)), // Wider gap
            SliverToBoxAdapter(
              child: _buildSniffAroundSection(context, ref),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80), // Bottom padding for FAB/Nav
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> statsAsync,
    AsyncValue<List<Map<String, dynamic>>> playdatesAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDashboardItem(
            context,
            icon: Icons.calendar_today_outlined,
            label: 'Playdates',
            value: playdatesAsync.value?.length.toString() ?? '-',
          ),
          _buildDashboardItem(
            context,
            icon: Icons.pets_outlined,
            label: 'Barks',
            value: statsAsync.value?['barks'].toString() ?? '-',
          ),
          _buildDashboardItem(
            context,
            icon: Icons.notifications_none_outlined,
            label: 'Alerts',
            value: '2', // Mocked
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h2().copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall().copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.h2().copyWith(fontSize: 22)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              'Show all',
              style: AppTypography.bodyMedium().copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the "Find Your Pack" search bar (clean, just the search field)
  Widget _buildPackSearchBar(BuildContext context) {
    // Just the search bar - filter chips are inside the modal as tabs
    return GestureDetector(
      onTap: () {
        _showPackSearchSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 20,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 12),
            Text(
              'Find your pack...',
              style: AppTypography.bodyMedium().copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PackSearchModal(),
    );
  }

  Widget _buildEmptyHorizontalState(BuildContext context, String message, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodySmall().copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaydateCard(BuildContext context, Map<String, dynamic> playdate) {
    final date = DateTime.tryParse(playdate['date_time'] ?? playdate['scheduled_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, h:mm a').format(date);
    final playdateId = playdate['id'] as String?;
    
    return GestureDetector(
      onTap: () {
        if (playdateId != null) {
          context.push('/playdate-details', extra: playdate);
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Text(
              playdate['location'] ?? 'Unknown Location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: 4),
            Text(
              playdate['status'] ?? 'pending',
              style: AppTypography.bodySmall().copyWith(
                color: _getStatusColor(context, playdate['status']),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStatusColor(BuildContext context, String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'declined':
      case 'cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
  Widget _buildEventCard(BuildContext context, dynamic event) {
    // Assuming event is an Event object or Map
    final title = event is Map ? event['title'] : event.title;
    final date = event is Map 
        ? DateTime.tryParse(event['date_time'] ?? '') ?? DateTime.now()
        : event.dateTime;
    final formattedDate = DateFormat('MMM d, h:mm a').format(date);
    final location = event is Map ? event['location'] : event.location;

    return GestureDetector(
      onTap: () {
        context.push('/event-details', extra: event);
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title ?? 'Untitled Event',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium().copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              location ?? 'Unknown Location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the "Sniff Around" social feed preview section
  Widget _buildSniffAroundSection(BuildContext context, WidgetRef ref) {
    // Get user's first dog for personalization
    final userDogsAsync = ref.watch(userDogsProvider);
    
    return userDogsAsync.when(
      data: (dogs) {
        final firstDog = dogs.isNotEmpty ? dogs.first : null;
        final dogName = firstDog?.name ?? 'your pup';
        final dogPhoto = firstDog?.photos.isNotEmpty == true ? firstDog!.photos.first : null;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with emoji and "See All"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🐕', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text('Sniff Around', style: AppTypography.h2()),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/social-feed'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('See All'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'See what the pack is up to',
                style: AppTypography.bodyMedium().copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              
              // Create Post CTA - Opens create post dialog
              GestureDetector(
                onTap: () => context.push('/social-feed?create=true'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Dog's photo or fallback
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: dogPhoto != null ? NetworkImage(dogPhoto) : null,
                        child: dogPhoto == null
                            ? Icon(Icons.pets, size: 18, color: Theme.of(context).colorScheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Share $dogName's moments...",
                          style: AppTypography.bodyMedium().copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.photo_library_outlined,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              // Quick action buttons with proper navigation
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/social-feed?tab=0'), // For You tab
                      icon: const Text('🦴', style: TextStyle(fontSize: 16)),
                      label: const Text('Browse Feed'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/social-feed?tab=1'), // Following tab
                      icon: const Icon(Icons.group_outlined, size: 18),
                      label: const Text('Friends'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Toggle between Friends and All Dogs in Nearby section
class _NearbyDogsToggle extends StatefulWidget {
  @override
  State<_NearbyDogsToggle> createState() => _NearbyDogsToggleState();
}

class _NearbyDogsToggleState extends State<_NearbyDogsToggle> {
  int _selectedIndex = 1; // 0 = Friends, 1 = All (default to All)
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleButton(0, 'My Pack', Icons.group),
          _buildToggleButton(1, 'All Dogs', Icons.pets),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search modal with filter tabs (All, Friends, Nearby, New)
class _PackSearchModal extends StatefulWidget {
  @override
  State<_PackSearchModal> createState() => _PackSearchModalState();
}

class _PackSearchModalState extends State<_PackSearchModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  final List<Map<String, dynamic>> _tabs = [
    {'label': 'All', 'icon': Icons.pets},
    {'label': 'Friends', 'icon': Icons.group},
    {'label': 'Nearby', 'icon': Icons.location_on},
    {'label': 'New', 'icon': Icons.auto_awesome},
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search dogs, friends...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                // TODO: Trigger search
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),
          
          // Filter tabs - fit all 4 without scrolling
          TabBar(
            controller: _tabController,
            isScrollable: false, // Stretch to fit all tabs
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.zero, // No extra padding
            tabs: _tabs.map((tab) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'] as IconData, size: 16),
                  const SizedBox(width: 4),
                  Text(tab['label'] as String, style: const TextStyle(fontSize: 13)),
                ],
              ),
            )).toList(),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Dogs
                _buildSearchResults(scrollController, 'All Dogs'),
                // Friends
                _buildSearchResults(scrollController, 'Friends'),
                // Nearby
                _buildSearchResults(scrollController, 'Nearby Dogs'),
                // New
                _buildSearchResults(scrollController, 'New Dogs'),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults(ScrollController controller, String category) {
    final query = _searchController.text;
    
    if (query.isEmpty) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recent $category', style: AppTypography.labelMedium()),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.pets, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'Start typing to search $category...',
                  style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    // TODO: Implement actual search results
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(16),
      children: [
        Text('Results for "$query" in $category', style: AppTypography.labelMedium()),
        const SizedBox(height: 16),
        // Placeholder for search results
        Center(
          child: Text(
            'Searching...',
            style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
