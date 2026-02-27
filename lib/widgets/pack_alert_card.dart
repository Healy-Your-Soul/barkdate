import 'package:flutter/material.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/design_system/app_typography.dart';

/// A single colored alert card matching the design:
/// - Rounded dark-colored container
/// - Emoji icon top-left + bold white headline
/// - White body text (slightly translucent)
/// - Optional white pill CTA button at the bottom
class PackAlertCard extends StatelessWidget {
  final FriendAlert alert;
  final VoidCallback? onCtaTapped;
  final VoidCallback? onCardTapped;

  const PackAlertCard({
    super.key,
    required this.alert,
    this.onCtaTapped,
    this.onCardTapped,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTapped,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: alert.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: alert.backgroundColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon + Headline row
            Row(
              children: [
                // Emoji icon
                Text(
                  alert.iconEmoji ?? FriendAlert.emojiForType(alert.type),
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                // Headline
                Expanded(
                  child: Text(
                    alert.headline,
                    style: AppTypography.h3(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Body text
            Text(
              alert.body,
              style: AppTypography.bodyMedium(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // CTA button
            if (alert.ctaLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCtaTapped,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: alert.backgroundColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    alert.ctaLabel!,
                    style: AppTypography.labelMedium(
                      color: alert.backgroundColor,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
