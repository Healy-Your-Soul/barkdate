import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/widgets/location_settings_widget.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/screens/terms_of_service_screen.dart';
import 'package:barkdate/features/settings/presentation/screens/blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadSearchRadius();
  }

  Future<void> _loadSearchRadius() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    try {
      await SupabaseService.selectSingle('users', filters: {'id': user.id});
      if (!mounted) return;
    } catch (e) {
      debugPrint('Error loading search radius: $e');
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
                  await SupabaseAuth.signOut();
                  if (userId != null) {
                    SupabaseAuthWrapper.clearProfileCache(userId);
                  }
                  if (context.mounted) {
                    context.go('/auth');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign out failed: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
              'Are you absolutely sure you want to delete your account?'),
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      if (user == null) return;

      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

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

      await BarkDateUserService.deleteUserAccount(user.id);

      if (mounted) navigator.pop();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green),
        );
        context.go('/auth');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTypography.h1().copyWith(fontSize: 28),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            _buildSectionHeader(context, 'Account'),
            _buildSettingsItem(
              context,
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Manage your profile information',
              onTap: () async {
                final user = SupabaseConfig.auth.currentUser;
                if (user != null) {
                  final userProfile = await SupabaseService.selectSingle(
                      'users',
                      filters: {'id': user.id});
                  if (mounted) {
                    context.push('/create-profile', extra: {
                      'editMode': EditMode.editOwner,
                      'userName': userProfile?['name'],
                      'userEmail': userProfile?['email'] ?? user.email,
                      'userId': user.id,
                    });
                  }
                }
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.pets_outlined,
              title: 'My Dogs',
              subtitle: 'Manage your dog profiles',
              onTap: () {
                context.push('/create-profile',
                    extra: {'editMode': EditMode.editDog});
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.settings_outlined,
              title: 'App Preferences',
              subtitle: 'Manage your app preferences',
              onTap: () => _showAppPreferencesSheet(context),
            ),
            _buildSettingsItem(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy',
              subtitle: 'Manage your privacy settings',
              onTap: () => _showPrivacySheet(context),
            ),

            const Divider(height: 48),

            _buildSectionHeader(context, 'Location'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LocationSettingsWidget(
                onLocationChanged: () {
                  final userId = SupabaseConfig.auth.currentUser?.id;
                  if (userId != null) {
                    CacheService()
                      ..invalidate('nearby_$userId')
                      ..invalidateFeedSnapshot(userId);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Location settings updated. Pull to refresh your feed.')),
                    );
                  }
                },
              ),
            ),

            const Divider(height: 48),

            // Privacy & Safety Section
            _buildSectionHeader(context, 'Privacy & Safety'),
            _buildSettingsItem(
              context,
              icon: Icons.block_outlined,
              title: 'Blocked Users',
              subtitle: 'Manage blocked accounts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BlockedUsersScreen()),
                );
              },
            ),

            const Divider(height: 48),

            _buildSectionHeader(context, 'Support'),
            _buildSettingsItem(
              context,
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'Get help with the app',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help Center - Coming soon!')),
                );
              },
            ),
            _buildSettingsItem(
              context,
              icon: Icons.email_outlined,
              title: 'Contact Us',
              subtitle: 'Contact us for support',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Contact support: support@barkdate.com')),
                );
              },
            ),

            const Divider(height: 48),

            _buildSectionHeader(context, 'Legal'),
            _buildSettingsItem(
              context,
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TermsOfServiceScreen()),
                );
              },
            ),

            const SizedBox(height: 32),

            _buildSectionHeader(context, 'Danger Zone'),
            _buildSettingsItem(
              context,
              icon: Icons.delete_forever,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: () => _showDeleteAccountDialog(context),
              isDestructive: true,
            ),

            const SizedBox(height: 24),

            Center(
              child: Text(
                'BarkDate v1.0.0',
                style: AppTypography.caption().copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showSignOutDialog(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Log Out',
                    style: AppTypography.labelLarge()
                        .copyWith(color: Colors.black),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        title,
        style: AppTypography.h3().copyWith(fontSize: 20),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon,
                size: 24,
                color: isDestructive
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge().copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall().copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showAppPreferencesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _settingsService,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('App Preferences', style: AppTypography.h2()),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: widget.scrollController,
                    children: [
                      Text('Appearance', style: AppTypography.h3()),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Theme', style: AppTypography.bodyLarge()),
                        subtitle: Text(
                          'Dark mode coming soon',
                          style: AppTypography.caption().copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '☀️ Light',
                            style: AppTypography.labelMedium().copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Notifications', style: AppTypography.h3()),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Push Notifications',
                            style: AppTypography.bodyLarge()),
                        value: _settingsService.notificationsEnabled,
                        onChanged: (value) =>
                            _settingsService.setNotificationsEnabled(value),
                        activeThumbColor: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}

class PrivacySheet extends StatefulWidget {
  final ScrollController scrollController;

  const PrivacySheet({super.key, required this.scrollController});

  @override
  State<PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<PrivacySheet> {
  final _settingsService = SettingsService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _settingsService,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Privacy Settings', style: AppTypography.h2()),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: widget.scrollController,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Location Sharing',
                            style: AppTypography.bodyLarge()),
                        subtitle: Text(
                            'Allow others to see your general location',
                            style: AppTypography.bodySmall()),
                        value: _settingsService.locationEnabled,
                        onChanged: (value) =>
                            _settingsService.setLocationEnabled(value),
                        activeThumbColor: Colors.black,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Privacy Mode',
                            style: AppTypography.bodyLarge()),
                        subtitle: Text('Limit who can see your profile',
                            style: AppTypography.bodySmall()),
                        value: _settingsService.privacyMode,
                        onChanged: (value) =>
                            _settingsService.setPrivacyMode(value),
                        activeThumbColor: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}
