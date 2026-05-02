import 'package:flutter/material.dart';

/// Compact info + action popup shown from a confirmed walk indicator on a
/// dog card. Tighter than the previous version — no sprawling hero, no
/// overflowing buttons. Primary action is "Let's chat"; reschedule and
/// cancel are secondary text actions at the bottom.
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

  static const _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final hasDescription = (playdate['description'] as String?)?.isNotEmpty ?? false;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          minWidth: size.width * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Slim header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle,
                        size: 20, color: _green),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Walk Confirmed',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    theme,
                    Icons.location_on,
                    playdate['location'] as String? ?? 'Location TBD',
                  ),
                  const SizedBox(height: 10),
                  _infoRow(
                    theme,
                    Icons.access_time,
                    _formatDateTime(playdate['scheduled_at'] as String?),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 10),
                    _infoRow(
                      theme,
                      Icons.notes,
                      playdate['description'] as String,
                    ),
                  ],
                ],
              ),
            ),

            // ── Primary action ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    "Let's chat",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // ── Tertiary actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onReschedule,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                      ),
                      child: const Text(
                        'Reschedule',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      child: const Text(
                        'Cancel walk',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.hintColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Time TBD';
    try {
      final dt = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      String dateStr;
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        dateStr = 'Today';
      } else if (dt.year == tomorrow.year &&
          dt.month == tomorrow.month &&
          dt.day == tomorrow.day) {
        dateStr = 'Tomorrow';
      } else {
        dateStr = '${dt.month}/${dt.day}/${dt.year}';
      }

      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$dateStr at $displayHour:$minute $period';
    } catch (_) {
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
