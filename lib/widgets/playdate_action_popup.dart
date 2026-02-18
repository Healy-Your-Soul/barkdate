import 'package:flutter/material.dart';
import 'package:barkdate/widgets/app_button.dart';

/// Beautiful popup for confirmed playdates with action buttons
/// Inspired by Flutter_beautiful_popup templates
class PlaydateActionPopup extends StatelessWidget {
  final Map<String, dynamic> playdate;
  final VoidCallback? onReschedule;
  final VoidCallback? onChat;
  final VoidCallback? onCancel;

  const PlaydateActionPopup({
    super.key,
    required this.playdate,
    this.onReschedule,
    this.onChat,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 32,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Playdate Confirmed! 🎉',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, color: theme.hintColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playdate['location'] ?? 'Location TBD',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Time
                  Row(
                    children: [
                      Icon(Icons.access_time, color: theme.hintColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatDateTime(playdate['scheduled_at']),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),

                  if (playdate['description'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes, color: theme.hintColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            playdate['description'],
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Primary actions row
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Chat',
                          icon: Icons.chat_bubble,
                          onPressed: onChat,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: 'Reschedule',
                          icon: Icons.schedule,
                          customColor: Colors.orange,
                          onPressed: onReschedule,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Secondary actions
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: 'Cancel Playdate',
                          type: AppButtonType.text,
                          customColor: Colors.red,
                          onPressed: onCancel,
                        ),
                      ),
                      Expanded(
                        child: AppButton(
                          text: 'Close',
                          type: AppButtonType.text,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
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

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Time TBD';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      String dateStr;
      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        dateStr = 'Today';
      } else if (dateTime.year == tomorrow.year &&
          dateTime.month == tomorrow.month &&
          dateTime.day == tomorrow.day) {
        dateStr = 'Tomorrow';
      } else {
        dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      }

      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$dateStr at $displayHour:$minute $period';
    } catch (e) {
      return dateTimeStr;
    }
  }

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> playdate,
    VoidCallback? onReschedule,
    VoidCallback? onChat,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PlaydateActionPopup(
        playdate: playdate,
        onReschedule: onReschedule,
        onChat: onChat,
        onCancel: onCancel,
      ),
    );
  }
}
