import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_typography.dart';

class WalkMarkerTooltip extends StatelessWidget {
  final String dogName;
  final String? inviteeDogName;
  final String time;
  final String parkName;
  final bool isConfirmed;
  final VoidCallback onTap;

  const WalkMarkerTooltip({
    super.key,
    required this.dogName,
    this.inviteeDogName,
    required this.time,
    required this.parkName,
    required this.isConfirmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleText = isConfirmed && inviteeDogName != null
        ? '$dogName & $inviteeDogName • $time'
        : '$dogName • $time';

    final iconColor =
        isConfirmed ? const Color(0xFF0D47A1) : const Color(0xFF64B5F6);
    final iconData = isConfirmed ? Icons.pets : Icons.access_time;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(
            bottom: 16), // space between marker and tooltip
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: AppTypography.bodyMedium(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parkName,
                  style: AppTypography.bodySmall(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Chevron
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
