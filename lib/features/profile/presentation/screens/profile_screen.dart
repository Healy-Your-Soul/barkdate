import 'package:flutter/material.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/profile/presentation/widgets/share_dog_sheet.dart';
import 'package:barkdate/features/profile/presentation/providers/profile_provider.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/core/config/app_constants.dart';

import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/screens/help_screen.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';
import 'package:barkdate/features/profile/presentation/screens/dog_details_screen.dart';

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
            ref.invalidate(userStatsProvider);
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
                              final dogs = userDogsAsync.value;
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
                                // Avatar + name column act as one tap target
                                // that jumps straight to the full-page owner
                                // edit (dog-details style). No bottom sheet.
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _openOwnerEdit(context),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundImage:
                                                profile['avatar_url'] != null
                                                    ? NetworkImage(
                                                        profile['avatar_url'])
                                                    : null,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: profile['avatar_url'] == null
                                                ? const Icon(Icons.person,
                                                    size: 24,
                                                    color: Colors.grey)
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
                                                  profile[
                                                          'relationship_status'] ??
                                                      'Human',
                                                  style:
                                                      AppTypography.bodySmall()
                                                          .copyWith(
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
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 20, color: Colors.grey),
                                  tooltip: 'Edit profile',
                                  onPressed: () => _openOwnerEdit(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Add Dog Button — opens the DogDetailsScreen
                                // in "new dog" mode for the current user, so
                                // the add-a-dog UI matches the edit UI.
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openAddDog(context, ref),
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
                                      final dogs = userDogsAsync.value;
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
                      onTap: () => const SettingsRoute().go(context),
                    ),
                    if (AppConstants.adminEmails
                        .contains(SupabaseConfig.auth.currentUser?.email))
                      _buildMenuItem(
                        context,
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Admin Panel',
                        onTap: () => const AdminRoute().push(context),
                      ),
                    _buildMenuItem(
                      context,
                      icon: Icons.rss_feed,
                      title: 'Social Feed',
                      onTap: () => const ProfileSocialFeedRoute().go(context),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      onTap: () => const AchievementsRoute().push(context),
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
                          const AuthRoute().go(context);
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

  /// Open the full-page owner edit screen (dog-details style) that replaces
  /// the old quick-edit bottom sheet. Invoked from both the owner row tap
  /// target and the pencil icon.
  void _openOwnerEdit(BuildContext context) {
    CreateProfileRoute(
      editMode: EditMode.editOwner,
      userId: SupabaseConfig.auth.currentUser?.id,
    ).push(context);
  }

  /// Launch the "Add a new dog" flow using the DogDetailsScreen in
  /// [DogDetailsScreen.newDog] mode so the add UI matches the edit UI.
  Future<void> _openAddDog(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DogDetailsScreen.newDog(),
      ),
    );
    // When the user successfully adds a dog the screen already invalidates
    // providers; these redundant calls are cheap and cover any early-return
    // paths (e.g. if the navigator popped without saving).
    ref.invalidate(userDogsProvider);
    ref.invalidate(userProfileProvider);
  }

  Widget _buildLargeDogCard(BuildContext context, WidgetRef ref, dynamic dog) {
    return GestureDetector(
      onTap: () {
        DogDetailsRoute($extra: dog).push(context);
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
            // Direct edit shortcut -> DogDetailsScreen in edit mode.
            // Delete intentionally lives only inside the full dog profile page.
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 22, color: Colors.grey),
                tooltip: 'Edit dog profile',
                splashRadius: 22,
                onPressed: () {
                  DogDetailsRoute(
                    $extra: dog,
                    startInEditMode: true,
                  ).push(context).then((_) {
                    ref.invalidate(userDogsProvider);
                    ref.invalidate(userProfileProvider);
                  });
                },
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
                      // Playdates - fetches count dynamically
                      Consumer(
                        builder: (context, ref, _) {
                          final statsAsync = ref.watch(userStatsProvider);
                          final count = statsAsync.value?['playdates'] ?? 0;
                          return _buildAirbnbStat('$count', 'Playdates');
                        },
                      ),
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
        const CreateProfileRoute(
          editMode: EditMode.createProfile,
        ).push(context);
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
