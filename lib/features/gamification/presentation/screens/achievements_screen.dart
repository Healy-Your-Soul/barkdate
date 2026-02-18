import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/data/sample_data.dart';
import 'package:barkdate/models/playdate.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Clean header with trophy icon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                children: [
                  // Trophy icon in soft circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      size: 40,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Level Up Your Pup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Earn badges for completing activities and engaging with the Sniff Around community!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Achievements grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: SampleData.achievements.length,
                itemBuilder: (context, index) {
                  final achievement = SampleData.achievements[index];
                  return _buildAchievementCard(context, achievement);
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, Achievement achievement) {
    final isEarned = achievement.isEarned;
    final primary = Theme.of(context).colorScheme.primary;

    // Colors based on earned status
    final Color cardBgColor;
    final Color iconBgColor;
    final Color iconColor;

    if (isEarned) {
      // Subtle green for earned
      cardBgColor = const Color(0xFFF0FFF4); // Very subtle mint green
      iconBgColor = const Color(0xFFD1FAE5); // Soft green
      iconColor = const Color(0xFF059669); // Green-600
    } else {
      cardBgColor = Colors.white;
      iconBgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade400;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in soft circle
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _getAchievementIcon(achievement.iconName),
                size: 28,
                color: iconColor,
              ),
            ),

            const SizedBox(height: 14),

            // Title
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isEarned ? Colors.black87 : Colors.grey[600],
              ),
            ),

            const SizedBox(height: 6),

            // Description
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Status indicator
            if (isEarned) ...[
              // Earned badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
                  const SizedBox(width: 4),
                  Text(
                    achievement.earnedDate != null
                        ? 'Earned ${_formatTimeAgo(achievement.earnedDate!)}'
                        : 'Earned',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Progress bar for in-progress achievements
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _getMockProgress(achievement),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getMockProgressText(achievement),
                    style: TextStyle(
                      fontSize: 11,
                      color: primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'pets':
        return Icons.pets;
      case 'park':
        return Icons.park;
      case 'group':
        return Icons.group;
      case 'star':
        return Icons.star;
      case 'calendar':
        return Icons.calendar_today;
      case 'trophy':
        return Icons.emoji_events;
      case 'camera':
        return Icons.camera_alt;
      case 'explore':
        return Icons.explore;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'just now';
    }
  }

  // Mock progress for demo - would come from real data
  double _getMockProgress(Achievement achievement) {
    switch (achievement.iconName) {
      case 'group':
        return 0.6; // 3/5 friends
      case 'star':
        return 0.42; // 42/100 likes
      case 'camera':
        return 0.4; // 2/5 photos
      case 'explore':
        return 0.6; // 3/5 parks
      default:
        return 0.3;
    }
  }

  String _getMockProgressText(Achievement achievement) {
    switch (achievement.iconName) {
      case 'group':
        return '3/5 Friends';
      case 'star':
        return '42/100 Likes';
      case 'camera':
        return '2/5 Photos';
      case 'explore':
        return '3/5 Parks';
      default:
        return 'In Progress';
    }
  }
}
