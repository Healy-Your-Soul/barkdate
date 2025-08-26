import 'package:flutter/material.dart';
import 'package:barkdate/screens/achievements_screen.dart';
import 'package:barkdate/screens/playdates_screen.dart';
import 'package:barkdate/screens/premium_screen.dart';
import 'package:barkdate/screens/social_feed_screen.dart';
import 'package:barkdate/screens/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: Theme.of(context).colorScheme.onTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alex Johnson',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dog lover & adventure seeker',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(context, '23', 'Playdates'),
                      _buildStatItem(context, '89', 'Friends'),
                      _buildStatItem(context, '156', 'Posts'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // My Dog section
            _buildMyDogSection(context),
            
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
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMyDogSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Dog',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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
                  child: Icon(
                    Icons.pets,
                    size: 30,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Luna',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Golden Retriever, 3 years old',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Friendly and loves to play fetch!',
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
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
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}