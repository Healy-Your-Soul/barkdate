import 'package:flutter/material.dart';
import 'package:barkdate/screens/achievements_screen.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/premium_screen.dart';
import 'package:barkdate/screens/social_feed_screen.dart';
import 'package:barkdate/screens/settings_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/widgets/dog_share_dialog.dart';
import 'package:barkdate/widgets/app_card.dart';
import 'package:barkdate/widgets/app_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _dogProfile;
  bool _isLoading = true;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Don't load data here - wait for didChangeDependencies to ensure screen is visible
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only load once when screen becomes visible
    if (!_hasInitialized) {
      _hasInitialized = true;
      
      // Check if this route is currently active/visible
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        _loadProfileData();
      }
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      // Load user profile
      final userProfile = await SupabaseService.selectSingle(
        'users',
        filters: {'id': user.id},
      );

      // Load user's dog (first dog for now) - using proper service method
      final dogs = await BarkDateUserService.getUserDogs(user.id);

      setState(() {
        _userProfile = userProfile;
        _dogProfile = dogs.isNotEmpty ? dogs.first : null;
        _isLoading = false;
      });
      
      // Debug logging
      debugPrint('=== PROFILE SCREEN DEBUG ===');
      debugPrint('User profile data: ${userProfile?.toString()}');
      debugPrint('User avatar URL: ${userProfile?['avatar_url']}');
      debugPrint('Found ${dogs.length} dogs for user');
      if (dogs.isNotEmpty) {
        debugPrint('Dog profile data: ${dogs.first.toString()}');
        debugPrint('Dog main photo URL: ${dogs.first['main_photo_url']}');
        debugPrint('Dog name: ${dogs.first['name']}');
      } else {
        debugPrint('No dogs found for user!');
      }
      debugPrint('=== END PROFILE SCREEN DEBUG ===');
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Single edit navigation function - unified for all editing
  Future<void> _editProfile({
    required EditMode mode,
    String? title,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProfileScreen(
          userId: SupabaseConfig.auth.currentUser?.id,
          editMode: mode,
        ),
      ),
    );
    
    if (result == true) {
      _loadProfileData(); // Refresh data
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onSelected: (value) async {
              switch (value) {
                case 'edit_dog':
                  await _editProfile(mode: EditMode.editDog);
                  break;
                case 'edit_human':
                  await _editProfile(mode: EditMode.editOwner);
                  break;
                case 'edit_both':
                  await _editProfile(mode: EditMode.editBoth);
                  break;
                case 'add_dog':
                  await _editProfile(mode: EditMode.createProfile);
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit_dog',
                child: Row(
                  children: [
                    Icon(Icons.pets),
                    SizedBox(width: 12),
                    Text('Edit Dog Profile'),
                  ],
                ),
              ),
              if (_dogProfile == null)
                const PopupMenuItem(
                  value: 'add_dog',
                  child: Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 12),
                      Text('Add Dog Profile'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit_human',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 12),
                    Text('Edit My Human'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_both',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 12),
                    Text('Edit All'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dog hero image with overlay
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: AppImageCard(
                imageUrl: _dogProfile?['main_photo_url'] != null &&
                        _dogProfile!['main_photo_url'].toString().isNotEmpty
                    ? _dogProfile!['main_photo_url']
                    : null,
                height: 220,
                overlay: Positioned(
                  top: 12,
                  right: 12,
                  child: AppButton(
                    text: _dogProfile == null ? 'Add Dog' : 'Edit Dog',
                    size: AppButtonSize.small,
                    onPressed: () => _editProfile(mode: _dogProfile != null ? EditMode.editDog : EditMode.createProfile),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dogProfile?['name'] ?? 'Add Your Dog',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dogProfile?['bio'] ?? 'Your furry best friend',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Stats card
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem(context, '23', 'Playdates')),
                  Expanded(child: _buildStatItem(context, '89', 'Friends')),
                  Expanded(child: _buildStatItem(context, '156', 'Posts')),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // My Human section
            _buildMyHumanSection(context),
            
            const SizedBox(height: 24),
            
            // Menu items
            _buildMenuItem(
              context,
              icon: Icons.calendar_today,
              title: 'Playdates',
              subtitle: 'Manage your upcoming and past playdates',
              onTap: () => Navigator.push(
                context,
                                MaterialPageRoute(builder: (context) => const PlaydatesScreen()),
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.feed,
              title: 'Social Feed',
              subtitle: 'Your posts and community updates',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SocialFeedScreen()),
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.emoji_events,
              title: 'Achievements',
              subtitle: 'View your badges and milestones',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AchievementsScreen()),
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.star,
              title: 'Go Premium',
              subtitle: 'Unlock exclusive features and benefits',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              ),
              isPremium: true,
            ),
            _buildMenuItem(
              context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Get help with the app',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {},
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMyHumanSection(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Human',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    AppButton(
                      text: 'Share',
                      icon: Icons.share,
                      type: AppButtonType.outline,
                      size: AppButtonSize.small,
                      onPressed: () async {
                        // Share the current dog profile
                        if (_dogProfile != null) {
                          final dogId = _dogProfile!['id'];
                          final dogName = _dogProfile!['name'] ?? 'My Dog';
                          await DogShareDialog.open(
                            context,
                            dogId: dogId,
                            dogName: dogName,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please create a dog profile first to share'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      text: 'Edit',
                      type: AppButtonType.outline,
                      size: AppButtonSize.small,
                      onPressed: () => _editProfile(mode: EditMode.editOwner),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: _userProfile?['avatar_url'] != null && 
                                  _userProfile!['avatar_url'].toString().isNotEmpty &&
                                  !_userProfile!['avatar_url'].toString().contains('placeholder')
                      ? NetworkImage(_userProfile!['avatar_url'])
                      : null,
                  onBackgroundImageError: _userProfile?['avatar_url'] != null && 
                                         _userProfile!['avatar_url'].toString().isNotEmpty &&
                                         !_userProfile!['avatar_url'].toString().contains('placeholder')
                      ? (exception, stackTrace) {
                          debugPrint('Error loading owner avatar: $exception');
                        }
                      : null,
                  child: _userProfile?['avatar_url'] == null || 
                         _userProfile!['avatar_url'].toString().isEmpty ||
                         _userProfile!['avatar_url'].toString().contains('placeholder')
                      ? Icon(
                          Icons.person,
                          size: 30,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProfile?['name'] ?? 'My human\'s info coming soon',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userProfile?['location'] ?? 'Location not set',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userProfile?['bio'] ?? 'Dog lover & adventure seeker',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isPremium
                    ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2)
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPremium
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}