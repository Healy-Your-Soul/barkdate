import 'package:flutter/material.dart';

/// A celebratory toast overlay for earned achievements
class AchievementToast extends StatelessWidget {
  final String name;
  final String description;
  final String icon;
  final VoidCallback? onDismiss;

  const AchievementToast({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    this.onDismiss,
  });

  IconData _getIconData() {
    switch (icon.toLowerCase()) {
      case 'calendar':
        return Icons.calendar_today;
      case 'park':
        return Icons.park;
      case 'group':
        return Icons.group;
      case 'star':
        return Icons.star;
      case 'camera':
        return Icons.camera_alt;
      case 'explore':
        return Icons.explore;
      default:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber[600]!,
              Colors.orange[700]!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy icon with glow
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(),
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // "Achievement Unlocked!" header
            Text(
              '🎉 Achievement Unlocked!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            // Achievement name
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Dismiss button
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Awesome!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows an achievement toast as an overlay
void showAchievementToast(
  BuildContext context, {
  required String name,
  required String description,
  required String icon,
}) {
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 0,
      right: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: AchievementToast(
          name: name,
          description: description,
          icon: icon,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    ),
  );
  
  Overlay.of(context).insert(overlayEntry);
  
  // Auto-dismiss after 5 seconds
  Future.delayed(const Duration(seconds: 5), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}
