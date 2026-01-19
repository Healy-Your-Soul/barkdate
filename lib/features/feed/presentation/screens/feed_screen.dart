import 'package:flutter/material.dart';
import 'package:barkdate/widgets/dog_loading_widget.dart';
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
import 'package:barkdate/supabase/barkdate_services.dart';
import 'dart:async';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart' hide DogFriendshipService;

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
                            icon: Consumer(
                              builder: (context, ref, child) {
                                final unreadAsync = ref.watch(unreadNotificationCountProvider);
                                final unreadCount = unreadAsync.value ?? 0;
                                
                                return Badge(
                                  isLabelVisible: unreadCount > 0,
                                  label: Text('$unreadCount'),
                                  child: const Icon(Icons.notifications_none),
                                );
                              },
                            ),
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

            // 2. Nearby Dogs Section with integrated search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
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
                    // Integrated search bar
                    _buildPackSearchBar(context),
                    const SizedBox(height: AppSpacing.md),
                    // Friends / All Toggle
                    _NearbyDogsToggle(),
                  ],
                ),
              ),
            ),

            // Pending Friend Requests (only show in My Pack mode)
            Consumer(
              builder: (context, ref, _) {
                final filter = ref.watch(feedFilterProvider);
                if (!filter.showPackOnly) return const SliverToBoxAdapter(child: SizedBox.shrink());
                
                final pendingAsync = ref.watch(pendingFriendRequestsProvider);
                
                return pendingAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Icon(Icons.pets, size: 20, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Pack Requests',
                                  style: AppTypography.h3().copyWith(color: Colors.orange[700]),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${requests.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...requests.map((request) => _buildFriendRequestCard(context, ref, request)),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                );
              },
            ),

            // Nearby Dogs List
            nearbyDogsAsync.when(
              data: (dogs) {
                final filter = ref.watch(feedFilterProvider);
                final isPackMode = filter.showPackOnly;
                
                if (dogs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CuteEmptyState(
                        icon: isPackMode ? Icons.group_off : Icons.location_off,
                        title: isPackMode ? 'No Friends Nearby' : 'No Dogs Nearby',
                        message: isPackMode 
                            ? 'None of your pack members are nearby right now. Find new friends!'
                            : 'We couldn\'t find any dogs in your area. Try adjusting your filters or check back later!',
                        actionLabel: isPackMode ? 'Find Your Pack' : 'Adjust Filters',
                        onAction: () {
                          if (isPackMode) {
                            _showPackSearchSheet(context);
                          } else {
                            showFeedFilterSheet(context);
                          }
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
                          isFriend: isPackMode,
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
              loading: () => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DogLoadingWidget(size: 120),
                        const SizedBox(height: 16),
                        Text(
                          'Sniffing out your pack...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // 3. Upcoming Playdates Section (MOVED DOWN)
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
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: DogCircularProgress())),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 4. Suggested Events Section
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
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: DogCircularProgress())),
                  error: (_, __) => const SizedBox.shrink(),
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
            onTap: () => context.go('/playdates'),
          ),
          _buildDashboardItem(
            context,
            icon: Icons.pets_outlined,
            label: 'Barks',
            value: statsAsync.value?['barks'].toString() ?? '-',
            onTap: () => context.go('/messages'), // Navigate to messages/friends
          ),
          _buildDashboardItem(
            context,
            icon: Icons.notifications_none_outlined,
            label: 'Alerts',
            value: null, // Value managed by child builder
            onTap: () => context.go('/notifications'),
            valueBuilder: (context) => Consumer(
              builder: (context, ref, _) {
                 final unreadAsync = ref.watch(unreadNotificationCountProvider);
                 final statsAsync = ref.watch(userStatsProvider);
                 // Prefer stream, fallback to specific stats, fallback to 0
                 final count = unreadAsync.value ?? statsAsync.value?['alerts'] ?? 0;
                 return Text(
                  count.toString(),
                  style: AppTypography.h2().copyWith(fontSize: 24),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    WidgetBuilder? valueBuilder,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          if (valueBuilder != null)
            valueBuilder(context)
          else
            Text(
              value ?? '-',
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
      ),
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
    final status = playdate['status'] as String?;
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    final participantId = playdate['participant_id'] as String?;
    
    // Show action buttons if pending and user is the invitee (not organizer)
    final showActionButtons = status?.toLowerCase() == 'pending' && 
        currentUserId != null && 
        participantId == currentUserId;
    
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
                Expanded(
                  child: Text(
                    formattedDate,
                    style: AppTypography.bodySmall().copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playdate['location'] ?? 'Unknown Location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium(),
            ),
            const Spacer(),
            if (showActionButtons) ...[
              // Accept/Decline buttons for pending invites
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: OutlinedButton(
                        onPressed: () => _respondToPlaydate(context, playdateId!, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Decline', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () => _respondToPlaydate(context, playdateId!, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                status ?? 'pending',
                style: AppTypography.bodySmall().copyWith(
                  color: _getStatusColor(context, status),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respondToPlaydate(BuildContext context, String playdateId, bool accept) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return;

      // First, find the playdate_request for this playdate where user is the invitee
      final requests = await SupabaseConfig.client
          .from('playdate_requests')
          .select('id')
          .eq('playdate_id', playdateId)
          .eq('invitee_id', currentUserId)
          .eq('status', 'pending');

      if (requests.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No pending request found'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final requestId = requests.first['id'] as String;
      final response = accept ? 'accepted' : 'declined';
      
      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: requestId,
        userId: currentUserId,
        response: response,
      );
      
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? '✅ Playdate accepted!' : '❌ Playdate declined'),
            backgroundColor: accept ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  Widget _buildFriendRequestCard(BuildContext context, WidgetRef ref, Map<String, dynamic> request) {
    final requester = request['requester'] as Map<String, dynamic>?;
    final dogName = requester?['name'] ?? 'Unknown Dog';
    final dogPhoto = requester?['main_photo_url'] as String?;
    final ownerData = requester?['user'] as Map<String, dynamic>?;
    final ownerName = ownerData?['name'] ?? 'Unknown';
    final ownerAvatar = ownerData?['avatar_url'] as String?;
    final requestId = request['id'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stacked avatars (dog large + human small overlapping)
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main dog photo (large)
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: dogPhoto != null ? NetworkImage(dogPhoto) : null,
                  child: dogPhoto == null
                      ? Icon(Icons.pets, color: Colors.grey[400], size: 28)
                      : null,
                ),
                // Owner avatar (small, overlapping bottom-right)
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: ownerAvatar != null ? NetworkImage(ownerAvatar) : null,
                      child: ownerAvatar == null
                          ? Icon(Icons.person, color: Colors.grey[500], size: 14)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Text: "DogName & OwnerName want to join your pack"
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              children: [
                TextSpan(
                  text: '$dogName & $ownerName',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const TextSpan(text: ' want to join your pack'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Full-width buttons: Ignore (gray) | Accept (orange)
          Row(
            children: [
              // Ignore button
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final success = await BarkDateFriendService.declineFriendRequest(requestId);
                    if (success) {
                      ref.invalidate(pendingFriendRequestsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request declined'), backgroundColor: Colors.grey),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ignore', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              // Accept button
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await BarkDateFriendService.acceptFriendRequest(requestId);
                    if (success) {
                      ref.invalidate(pendingFriendRequestsProvider);
                      ref.invalidate(nearbyDogsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$dogName joined your pack! 🎉'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCF5EE), // Light orange/peach
                    foregroundColor: Colors.orange[800],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                      const AnimatedPawIcon(size: 28),
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
                      icon: Icon(Icons.pets, size: 18, color: Theme.of(context).colorScheme.primary),
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
class _NearbyDogsToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(feedFilterProvider);
    final isPackSelected = filter.showPackOnly;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleButton(context, ref, true, 'My Pack', Icons.group, isPackSelected),
          _buildToggleButton(context, ref, false, 'All Dogs', Icons.pets, !isPackSelected),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(BuildContext context, WidgetRef ref, bool packFilter, String label, IconData icon, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(feedFilterProvider.notifier).state = 
            ref.read(feedFilterProvider).copyWith(showPackOnly: packFilter);
        },
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
class _PackSearchModal extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PackSearchModal> createState() => _PackSearchModalState();
}

class _PackSearchModalState extends ConsumerState<_PackSearchModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _defaultContent = []; // Auto-loaded content for each tab
  bool _isLoading = false;
  bool _isLoadingDefault = false;
  String? _currentUserId;
  
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
    _tabController.addListener(_onTabChanged);
    _currentUserId = SupabaseConfig.auth.currentUser?.id;
    
    // Auto-load content for the initial tab
    _loadDefaultContent();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Re-run search with new category OR load default content
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      _loadDefaultContent();
    }
  }

  /// Load default content for the current tab (no search required)
  Future<void> _loadDefaultContent() async {
    if (_currentUserId == null) return;
    
    setState(() => _isLoadingDefault = true);
    
    try {
      final categoryIndex = _tabController.index;
      List<Map<String, dynamic>> results = [];
      
      switch (categoryIndex) {
        case 0: // All Dogs - show recent/popular dogs
          final response = await SupabaseConfig.client
              .from('dogs')
              .select('*, users:user_id(name, avatar_url)')
              .neq('user_id', _currentUserId!) // Exclude own dogs
              .order('created_at', ascending: false)
              .limit(20);
          results = List<Map<String, dynamic>>.from(response);
          break;
          
        case 1: // Friends - show ALL friends without search
          final userDogs = await BarkDateUserService.getUserDogs(_currentUserId!);
          if (userDogs.isNotEmpty) {
            final myDogId = userDogs.first['id'];
            final friends = await DogFriendshipService.getFriends(myDogId);
            
            // Map to dog objects
            results = friends.map((f) {
              return f['friend_dog']['id'] == myDogId 
                  ? f['dog'] as Map<String, dynamic>
                  : f['friend_dog'] as Map<String, dynamic>;
            }).toList();
          }
          break;
          
        case 2: // Nearby - show nearby dogs
          final nearby = await BarkDateMatchService.getNearbyDogs(
            _currentUserId!,
            limit: 20,
            radiusKm: 25,
          );
          results = nearby;
          break;
          
        case 3: // New - show newest dogs
          final response = await SupabaseConfig.client
              .from('dogs')
              .select('*, users:user_id(name, avatar_url)')
              .neq('user_id', _currentUserId!)
              .order('created_at', ascending: false)
              .limit(20);
          results = List<Map<String, dynamic>>.from(response);
          break;
      }
      
      if (mounted) {
        setState(() {
          _defaultContent = results;
          _isLoadingDefault = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading default content: $e');
      if (mounted) {
        setState(() => _isLoadingDefault = false);
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    
    // Cancel previous debounce if called directly (though usually called via debounce)
    
    try {
      final categoryIndex = _tabController.index;
      List<Map<String, dynamic>> results = [];
      
      switch (categoryIndex) {
        case 0: // All Dogs
          final response = await SupabaseConfig.client
              .from('dogs')
              .select('*, users:user_id(name, avatar_url)')
              .ilike('name', '%$query%')
              .order('name')
              .limit(20);
          results = List<Map<String, dynamic>>.from(response);
          break;
          
        case 1: // Friends
             // Get user's first dog to find friends
            final userDogs = await BarkDateUserService.getUserDogs(_currentUserId ?? '');
            if (userDogs.isEmpty) break;
            
            final myDogId = userDogs.first['id'];
            final friends = await DogFriendshipService.getFriends(myDogId);
            
            // Filter locally
            results = friends.where((f) {
              final friendDog = f['friend_dog']['id'] == myDogId ? f['dog'] : f['friend_dog'];
              final name = friendDog['name'].toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).map((f) {
               // Normalize to dog object structure
               return f['friend_dog']['id'] == myDogId ? f['dog'] : f['friend_dog'];
            }).cast<Map<String, dynamic>>().toList();
          break;
          
        case 2: // Nearby
          // Search nearby then filter locally
          final nearby = await BarkDateMatchService.getNearbyDogs(
             _currentUserId ?? '',
             limit: 50,
             radiusKm: 50, // Wider search for explicit nearby search
          );
          results = nearby.where((dog) {
            final name = dog['name'].toString().toLowerCase();
            return name.contains(query.toLowerCase());
          }).toList();
          break;
          
        case 3: // New
           final response = await SupabaseConfig.client
              .from('dogs')
              .select('*, users:user_id(name, avatar_url)')
              .ilike('name', '%$query%')
              .order('created_at', ascending: false)
              .limit(20);
          results = List<Map<String, dynamic>>.from(response);
          break;
      }
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching dogs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside text field
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
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
              onChanged: _onSearchChanged,
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
      ),
    );
  }
  
  Widget _buildSearchResults(ScrollController controller, String category) {
    final query = _searchController.text;
    
    // Show default content when no search query
    if (query.isEmpty) {
      // Show loading state for default content
      if (_isLoadingDefault) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DogLoadingWidget(size: 80),
              const SizedBox(height: 16),
              Text(
                'Loading $category...',
                style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
              ),
            ],
          ),
        );
      }
      
      // Show empty state if no default content
      if (_defaultContent.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                category == 'Friends' 
                    ? 'No friends yet. Bark at some dogs!' 
                    : 'No $category found',
                style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      
      // Show default content list
      return ListView.builder(
        controller: controller,
        padding: const EdgeInsets.all(16),
        itemCount: _defaultContent.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text('$category (${_defaultContent.length})', style: AppTypography.labelMedium()),
            );
          }
          
          final dog = _defaultContent[index - 1];
          // Ensure photos list is valid for DogCard
          if (dog['photos'] == null && dog['main_photo_url'] != null) {
            dog['photos'] = [dog['main_photo_url']];
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DogCard(
              dog: Dog.fromJson(dog),
              isFriend: false,
              onTap: () => context.push('/dog-details', extra: Dog.fromJson(dog)),
              onBarkPressed: () async {
                final currentUser = SupabaseConfig.auth.currentUser;
                if (currentUser == null) return;
                try {
                  final userDogs = await BarkDateUserService.getUserDogs(currentUser.id);
                  if (userDogs.isEmpty) return;
                  final myDogId = userDogs.first['id'];
                  final targetDog = Dog.fromJson(dog);
                  await DogFriendshipService.sendBark(fromDogId: myDogId, toDogId: targetDog.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Barked at ${targetDog.name}! 🐕'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                }
              },
              onPlaydatePressed: () => context.push('/create-playdate', extra: Dog.fromJson(dog)),
            ),
          );
        },
      );
    }
    
    // TODO: Implement actual search results
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DogLoadingWidget(size: 80),
            const SizedBox(height: 16),
            Text(
              'Fetching pups...',
              style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No dogs found for "$query"',
              style: AppTypography.bodyMedium().copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Found ${_searchResults.length} matches', style: AppTypography.labelMedium()),
          );
        }
        
        final dog = _searchResults[index - 1];
        // Ensure photos list is valid for DogCard
        if (dog['photos'] == null && dog['main_photo_url'] != null) {
          dog['photos'] = [dog['main_photo_url']];
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DogCard(
            dog: Dog.fromJson(dog),
            isFriend: false,
            onTap: () => context.push('/dog-details', extra: Dog.fromJson(dog)),
            onBarkPressed: () async {
              // Implement actual bark functionality
              final currentUser = SupabaseConfig.auth.currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to bark')),
                );
                return;
              }
              
              try {
                final userDogs = await BarkDateUserService.getUserDogs(currentUser.id);
                if (userDogs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add a dog profile first')),
                  );
                  return;
                }
                
                final myDogId = userDogs.first['id'];
                final targetDog = Dog.fromJson(dog);
                
                final success = await DogFriendshipService.sendBark(
                  fromDogId: myDogId,
                  toDogId: targetDog.id,
                );
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success 
                        ? 'Woof! Barked at ${targetDog.name}! 🐕' 
                        : 'Already barked at ${targetDog.name}'),
                      backgroundColor: success ? Colors.green : Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error sending bark: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send bark')),
                  );
                }
              }
            },
            onPlaydatePressed: () => context.push('/create-playdate', extra: Dog.fromJson(dog)),
          ),
        );
      },
    );
  }
}
