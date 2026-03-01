import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/core/config/app_constants.dart';
import 'package:barkdate/features/profile/presentation/widgets/share_dog_sheet.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
import 'package:barkdate/design_system/app_typography.dart';

import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/screens/help_screen.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final userDogsAsync = ref.watch(userDogsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileRepositoryProvider);
          },
          child: CustomScrollView(
            slivers: [
              // 1. Header "Profile"
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile',
                        style: AppTypography.h1().copyWith(fontSize: 32),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () {
                              final dogs = userDogsAsync.valueOrNull;
                              if (dogs != null && dogs.isNotEmpty) {
                                final dog = dogs.first;
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ShareDogSheet(
                                    dogId: dog.id,
                                    dogName: dog.name,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Add a dog first to share!')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. "My Dogs" Section (Hero) - Dog First!
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'My Pack',
                        style: AppTypography.h2(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 380, // Increased height for Airbnb-style card
                      child: userDogsAsync.when(
                        data: (dogs) {
                          if (dogs.isEmpty) {
                            return Center(
                              child: _buildAddDogCard(context, isLarge: true),
                            );
                          }
                          return Center(
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24.0),
                              scrollDirection: Axis.horizontal,
                              // If single item, center it. If multiple, let them scroll.
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: dogs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final dog = dogs[index];
                                return _buildLargeDogCard(context, ref, dog);
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 3. User Info (Secondary)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.5)),
                    ),
                    child: userProfileAsync.when(
                      data: (profile) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: profile['avatar_url'] != null
                                      ? NetworkImage(profile['avatar_url'])
                                      : null,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: profile['avatar_url'] == null
                                      ? const Icon(Icons.person,
                                          size: 24, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile['name'] ?? 'User',
                                        style: AppTypography.h3()
                                            .copyWith(fontSize: 18),
                                      ),
                                      Text(
                                        profile['relationship_status'] ??
                                            'Human',
                                        style:
                                            AppTypography.bodySmall().copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 20, color: Colors.grey),
                                  onPressed: () {
                                    context.push('/create-profile', extra: {
                                      'editMode': EditMode.editOwner
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Add Dog Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      context.push('/create-profile', extra: {
                                        'editMode': EditMode.addNewDog
                                      });
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Dog',
                                        style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Share Dog Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // Get the first dog to share (for now, simplistic approach)
                                      // In a real app with multiple dogs, we'd show a picker or share specific dog
                                      final dogs = userDogsAsync.valueOrNull;
                                      if (dogs != null && dogs.isNotEmpty) {
                                        final dog = dogs.first;
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) => ShareDogSheet(
                                            dogId: dog.id,
                                            dogName: dog.name,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Add a dog first to share!')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.share, size: 16),
                                    label: const Text('Share Dog',
                                        style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      backgroundColor: Colors
                                          .black, // Airbnb style primary action
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // 5. Menu List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'Account settings',
                      onTap: () => context.go('/profile/settings'),
                    ),
                    if (AppConstants.adminEmails
                        .contains(SupabaseConfig.auth.currentUser?.email))
                      _buildMenuItem(
                        context,
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Admin Panel',
                        onTap: () => context.push('/admin'),
                      ),
                    _buildMenuItem(
                      context,
                      icon: Icons.rss_feed,
                      title: 'Social Feed',
                      onTap: () => context.go('/profile/social-feed'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      onTap: () => context.push('/achievements'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline,
                      title: 'Get help',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HelpScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout,
                      title: 'Log out',
                      onTap: () async {
                        await SupabaseConfig.auth.signOut();
                        if (context.mounted) {
                          context.go('/auth');
                        }
                      },
                    ),
                  ]),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeDogCard(BuildContext context, WidgetRef ref, dynamic dog) {
    return GestureDetector(
      onTap: () {
        context.push('/dog-details', extra: dog);
      },
      child: Container(
        width: 280, // Much wider card
        margin: const EdgeInsets.only(bottom: 8), // Space for shadow
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 3-dots Menu (Edit + Delete)
            Positioned(
              top: 8,
              right: 8,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 24, color: Colors.grey),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result =
                        await context.push<bool>('/create-profile', extra: {
                      'editMode': EditMode.editDog,
                      'dogId': dog.id,
                    });
                    // Refresh dog list when returning from edit
                    if (result == true) {
                      ref.invalidate(userDogsProvider);
                      ref.invalidate(userProfileProvider);
                    }
                  } else if (value == 'delete') {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Dog Profile'),
                        content: Text(
                            'Are you sure you want to delete ${dog.name}\'s profile? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        // Get dog ID - handle both Dog model and Map
                        final dogId = dog is Map ? dog['id'] : dog.id;
                        debugPrint('🗑️ Deleting dog with ID: $dogId');
                        debugPrint('🗑️ Dog type: ${dog.runtimeType}');

                        if (dogId == null) {
                          throw Exception('Dog ID is null');
                        }

                        // Soft delete - set is_active to false
                        await SupabaseConfig.client
                            .from('dogs')
                            .update({'is_active': false}).eq('id', dogId);

                        debugPrint('✅ Dog marked as inactive');

                        // Clean up related records that reference this dog
                        try {
                          // Remove from playdate_participants
                          await SupabaseConfig.client
                              .from('playdate_participants')
                              .delete()
                              .eq('dog_id', dogId);
                          debugPrint(
                              '✅ Removed dog from playdate_participants');

                          // Remove from playdate_requests (where this dog was invited)
                          await SupabaseConfig.client
                              .from('playdate_requests')
                              .delete()
                              .eq('invitee_dog_id', dogId);
                          debugPrint(
                              '✅ Removed dog from playdate_requests (invitee)');

                          // Also clean up requester_dog_id if exists
                          await SupabaseConfig.client
                              .from('playdate_requests')
                              .delete()
                              .eq('requester_dog_id', dogId);
                          debugPrint(
                              '✅ Removed dog from playdate_requests (requester)');
                        } catch (cleanupError) {
                          debugPrint('⚠️ Cleanup warning: $cleanupError');
                        }

                        // Clear cache and refresh
                        final userId = SupabaseConfig.auth.currentUser?.id;
                        if (userId != null) {
                          BarkDateUserService.clearUserDogsCache(userId);
                        }
                        ref.invalidate(userDogsProvider);
                        ref.invalidate(userProfileProvider);
                        ref.invalidate(userStatsProvider);
                        ref.invalidate(profileRepositoryProvider);
                        ref.invalidate(
                            userPlaydatesProvider); // Also refresh playdates

                        debugPrint('✅ Cache cleared and providers invalidated');

                        if (context.mounted) {
                          final dogName = dog is Map ? dog['name'] : dog.name;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("$dogName's profile deleted")),
                          );
                        }
                      } catch (e) {
                        debugPrint('❌ Error deleting dog: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error deleting: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Large Circular Avatar with Badge
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(dog.photos.isNotEmpty
                                ? dog.photos.first
                                : 'https://via.placeholder.com/150'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50), // Bright green
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Name
                  Text(
                    dog.name,
                    style: AppTypography.h2().copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dog.breed,
                    style: AppTypography.bodySmall().copyWith(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),

                  // 3. Stats Row with dynamic pack count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAirbnbStat('6', 'Playdates'),
                      // Dogs in Pack - fetches friend count dynamically
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: DogFriendshipService.getFriends(dog.id),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return _buildAirbnbStat('$count', 'Pack');
                        },
                      ),
                      _buildAirbnbStat('${dog.age}', 'Years'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirbnbStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAddDogCard(BuildContext context, {bool isLarge = false}) {
    return GestureDetector(
      onTap: () {
        context.push('/create-profile',
            extra: {'editMode': EditMode.createProfile});
      },
      child: Container(
        width: isLarge ? 160 : 120,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                size: isLarge ? 40 : 32,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              'Add Dog',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isLarge ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.black87, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.black54),
      onTap: onTap,
    );
  }
}
