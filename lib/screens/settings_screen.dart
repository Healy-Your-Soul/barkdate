import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barkdate/screens/help_screen.dart';
import 'package:barkdate/screens/auth/sign_in_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/widgets/location_settings_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _searchRadiusKm = 25;
  bool _isLoadingRadius = true;

  @override
  void initState() {
    super.initState();
    _loadSearchRadius();
  }

  Future<void> _loadSearchRadius() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingRadius = false);
      return;
    }

    try {
      final profile = await SupabaseService.selectSingle('users', filters: {'id': user.id});
      if (!mounted) return;
      setState(() {
        _searchRadiusKm = (profile?['search_radius_km'] as int?) ?? 25;
        _isLoadingRadius = false;
      });
    } catch (e) {
      debugPrint('Error loading search radius: $e');
      if (!mounted) return;
      setState(() => _isLoadingRadius = false);
    }
  }

  Future<void> _updateSearchRadius(int radiusKm) async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _searchRadiusKm = radiusKm;
    });

    try {
      await SupabaseConfig.client
          .from('users')
          .update({'search_radius_km': radiusKm})
          .eq('id', userId);
      CacheService().invalidate('nearby_$userId');
    } catch (e) {
      debugPrint('Error updating search radius: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update search radius: $e')),
        );
      }
    }
  }


  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  final userId = SupabaseConfig.auth.currentUser?.id;
                  
                  // Real Supabase sign out! 🚪
                  await SupabaseAuth.signOut();
                  
                  // Clear profile status cache to prevent stale data on next sign-in
                  if (userId != null) {
                    SupabaseAuthWrapper.clearProfileCache(userId);
                  }
                  
                  // Navigate to sign in and clear all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SignInScreen()),
                    (route) => false,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign out failed: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Delete Account'),
          content: const Text(
            'This action cannot be undone. All your data will be permanently deleted:\n\n'
            '• Your profile and dog information\n'
            '• All posts and comments\n'
            '• Matches and messages\n'
            '• Playdates and achievements\n'
            '• Photos and uploaded files\n\n'
            'Are you absolutely sure you want to delete your account?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteUserAccount(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUserAccount(BuildContext context) async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Save navigator and messenger references before async operations
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Deleting account...'),
              ],
            ),
          );
        },
      );

      // Delete user account and all related data
      await BarkDateUserService.deleteUserAccount(user.id);

      // Close loading dialog
      if (mounted) navigator.pop();

      if (mounted) {
        // Show success message
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to sign in screen
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInScreen()),
          (route) => false,
        );
      }

    } catch (e) {
      // Close loading dialog if still mounted
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (navError) {
          // Navigator context might be invalid, ignore
        }
      }

      if (mounted) {
        // Show error message
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (msgError) {
          // ScaffoldMessenger context might be invalid, ignore
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Account Section
            _buildSectionHeader(context, 'Account'),
            _buildSettingsItem(
              context,
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Manage your profile information',
              onTap: () async {
                // Navigate to profile editing
                final user = SupabaseConfig.auth.currentUser;
                if (user != null) {
                  // Load current profile data
                  final userProfile = await SupabaseService.selectSingle(
                    'users',
                    filters: {'id': user.id},
                  );
                  
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateProfileScreen(editMode: EditMode.editOwner, 
                          userName: userProfile?['name'],
                          userEmail: userProfile?['email'] ?? user.email,
                          userId: user.id,
                          locationEnabled: true,
                        ),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please sign in to edit profile')),
                  );
                }
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.pets,
              title: 'My Dogs',
              subtitle: 'Manage your dog profiles',
              onTap: () async {
                // Navigate to dog management (same as profile editing for now)
                final user = SupabaseConfig.auth.currentUser;
                if (user != null) {
                  // Load current profile data
                  final userProfile = await SupabaseService.selectSingle(
                    'users',
                    filters: {'id': user.id},
                  );
                  
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateProfileScreen(editMode: EditMode.editOwner, 
                          userName: userProfile?['name'],
                          userEmail: userProfile?['email'] ?? user.email,
                          userId: user.id,
                          locationEnabled: true,
                        ),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please sign in to manage dogs')),
                  );
                }
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.settings_outlined,
              title: 'App Preferences',
              subtitle: 'Manage your app preferences',
              onTap: () {
                _showAppPreferencesSheet(context);
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'Manage your privacy settings',
              onTap: () {
                _showPrivacySheet(context);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Location Section
            _buildSectionHeader(context, 'Location'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LocationSettingsWidget(
                onLocationChanged: () {
                  // Invalidate cache when location changes
                  final userId = SupabaseConfig.auth.currentUser?.id;
                  if (userId != null) {
                    CacheService()
                      ..invalidate('nearby_$userId')
                      ..invalidateFeedSnapshot(userId);
                  }
                  
                  // Show feedback
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Location settings updated. Pull to refresh your feed.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Support Section
            _buildSectionHeader(context, 'Support'),
            _buildSettingsItem(
              context,
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get help with the app',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.email_outlined,
              title: 'Contact Us',
              subtitle: 'Contact us for support',
              onTap: () {
                // TODO: Open email or contact form
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact support: support@barkdate.com')),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Report a bug or issue',
              onTap: () {
                // TODO: Open bug report form
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bug report form - Coming soon!')),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.share_outlined,
              title: 'Invite Friends',
              subtitle: 'Share BarkDate with friends',
              onTap: () {
                // TODO: Open share dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature - Coming soon!')),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.star_outline,
              title: 'Rate App',
              subtitle: 'Rate us in the app store',
              onTap: () {
                // TODO: Open app store rating
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you for your feedback!')),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Legal Section
            _buildSectionHeader(context, 'Legal'),
            _buildSettingsItem(
              context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              onTap: () {
                // TODO: Show terms of service
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Terms of Service - Coming soon!')),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.policy_outlined,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                // TODO: Show privacy policy
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy Policy - Coming soon!')),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Danger Zone Section
            _buildSectionHeader(context, 'Danger Zone'),
            _buildSettingsItem(
              context,
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and all data',
              onTap: () => _showDeleteAccountDialog(context),
            ),
            
            const SizedBox(height: 24),
            
            // App version
            Text(
              'BarkDate v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            
            // Sign Out button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _showSignOutDialog(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }

  void _showAppPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return AppPreferencesSheet(scrollController: scrollController);
        },
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return PrivacySheet(scrollController: scrollController);
        },
      ),
    );
  }
}

class AppPreferencesSheet extends StatefulWidget {
  final ScrollController scrollController;

  const AppPreferencesSheet({super.key, required this.scrollController});

  @override
  State<AppPreferencesSheet> createState() => _AppPreferencesSheetState();
}

class _AppPreferencesSheetState extends State<AppPreferencesSheet> {
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    // Settings will be read from SettingsService directly
  }

  String _getThemeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, child) {
        return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'App Preferences',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                // Theme Settings
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeDisplayName(_settingsService.themeMode)),
                  trailing: DropdownButton<ThemeMode>(
                    value: _settingsService.themeMode,
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: const Text('System')),
                      DropdownMenuItem(value: ThemeMode.light, child: const Text('Light')),
                      DropdownMenuItem(value: ThemeMode.dark, child: const Text('Dark')),
                    ],
                    onChanged: (ThemeMode? mode) {
                      if (mode != null) {
                        _settingsService.setThemeMode(mode);
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 24),

                // Notifications
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive notifications on your device'),
                  value: _settingsService.notificationsEnabled,
                  onChanged: (value) => _settingsService.setNotificationsEnabled(value),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy
                Text(
                  'Privacy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Location Sharing'),
                  subtitle: const Text('Allow others to see your general location'),
                  value: _settingsService.locationEnabled,
                  onChanged: (value) => _settingsService.setLocationEnabled(value),
                ),
                SwitchListTile(
                  title: const Text('Privacy Mode'),
                  subtitle: const Text('Limit who can see your profile'),
                  value: _settingsService.privacyMode,
                  onChanged: (value) => _settingsService.setPrivacyMode(value),
                ),
                
                const SizedBox(height: 24),
                
                // Search Preferences
                Text(
                  'Search',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const ListTile(
                  title: Text('Search Radius'),
                  subtitle: Text('25 miles'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: 25.0,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      onChanged: null, // TODO: Implement search radius setting
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
      }
    );
  }
}

class PrivacySheet extends StatefulWidget {
  final ScrollController scrollController;

  const PrivacySheet({super.key, required this.scrollController});

  @override
  State<PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<PrivacySheet> {
  bool _profileVisible = true;
  bool _showDistance = true;
  bool _allowMessages = true;
  bool _dataCollection = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Privacy Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                // Profile Visibility
                Text(
                  'Profile Visibility',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Profile Visible'),
                  subtitle: const Text('Allow others to discover your profile'),
                  value: _profileVisible,
                  onChanged: (value) => setState(() => _profileVisible = value),
                ),
                SwitchListTile(
                  title: const Text('Show Distance'),
                  subtitle: const Text('Display distance on your profile'),
                  value: _showDistance,
                  onChanged: (value) => setState(() => _showDistance = value),
                ),
                
                const SizedBox(height: 24),
                
                // Communication
                Text(
                  'Communication',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Allow Messages'),
                  subtitle: const Text('Allow others to send you messages'),
                  value: _allowMessages,
                  onChanged: (value) => setState(() => _allowMessages = value),
                ),
                
                const SizedBox(height: 24),
                
                // Data Collection
                Text(
                  'Data & Analytics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Analytics'),
                  subtitle: const Text('Help improve the app with usage data'),
                  value: _dataCollection,
                  onChanged: (value) => setState(() => _dataCollection = value),
                ),
                
                const SizedBox(height: 24),
                
                // Blocked Users
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Blocked Users'),
                  subtitle: const Text('Manage blocked users'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to blocked users list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Blocked users - Coming soon!')),
                    );
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete Account'),
                  subtitle: const Text('Permanently delete your account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Show delete account confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Delete account - Contact support')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
