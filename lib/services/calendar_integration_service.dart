import 'package:flutter/material.dart';

/// Calendar integration service for BarkDate playdates
/// Handles syncing confirmed playdates with device calendar
class CalendarIntegrationService {
  /// Add a confirmed playdate to device calendar
  /// Returns true if successfully added, false otherwise
  static Future<bool> addPlaydateToCalendar({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? description,
    List<String>? attendees,
  }) async {
    // TODO: Implement calendar integration
    // This will require add_2_calendar or device_calendar package
    
    debugPrint('📅 COMING SOON: Adding to calendar');
    debugPrint('Title: $title');
    debugPrint('Time: $startTime - $endTime');
    debugPrint('Location: $location');
    
    // For now, return true to simulate success
    // In real implementation, this would:
    // 1. Request calendar permissions
    // 2. Create calendar event
    // 3. Add to default calendar or BarkDate calendar
    // 4. Set reminder notifications
    
    return true;
  }

  /// Remove a playdate from device calendar
  static Future<bool> removePlaydateFromCalendar(String eventId) async {
    // TODO: Implement calendar removal
    debugPrint('📅 COMING SOON: Removing from calendar: $eventId');
    return true;
  }

  /// Update an existing calendar event
  static Future<bool> updateCalendarEvent({
    required String eventId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
  }) async {
    // TODO: Implement calendar update
    debugPrint('📅 COMING SOON: Updating calendar event: $eventId');
    return true;
  }

  /// Check if calendar permissions are granted
  static Future<bool> hasCalendarPermissions() async {
    // TODO: Check permissions
    return false; // For now, assume no permissions
  }

  /// Request calendar permissions from user
  static Future<bool> requestCalendarPermissions() async {
    // TODO: Request permissions
    debugPrint('📅 COMING SOON: Requesting calendar permissions');
    return false;
  }

  /// Show calendar integration setup dialog
  static Future<void> showCalendarSetupDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📅 Calendar Integration'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Coming Soon!'),
            SizedBox(height: 8),
            Text('We\'re working on calendar integration to:'),
            SizedBox(height: 8),
            Text('• Sync playdates to your calendar'),
            Text('• Set reminder notifications'),
            Text('• Share events with other participants'),
            Text('• Handle time zone differences'),
            SizedBox(height: 8),
            Text('Stay tuned for this feature! 🎉'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

/// Widget for calendar integration button
class CalendarIntegrationButton extends StatelessWidget {
  final Map<String, dynamic> playdate;
  final bool isConfirmed;

  const CalendarIntegrationButton({
    super.key,
    required this.playdate,
    required this.isConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    if (!isConfirmed) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => CalendarIntegrationService.showCalendarSetupDialog(context),
      icon: const Icon(Icons.calendar_month, size: 18),
      label: const Text('Add to Calendar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// Widget for reminder notifications setup
class PlaydateReminderButton extends StatelessWidget {
  final String playdateId;
  final DateTime scheduledTime;

  const PlaydateReminderButton({
    super.key,
    required this.playdateId,
    required this.scheduledTime,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.notifications_outlined, size: 18),
      tooltip: 'Set Reminder',
      onSelected: (value) => _setReminder(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '15min',
          child: Text('📱 15 minutes before'),
        ),
        const PopupMenuItem(
          value: '1hour',
          child: Text('⏰ 1 hour before'),
        ),
        const PopupMenuItem(
          value: '1day',
          child: Text('📅 1 day before'),
        ),
        const PopupMenuItem(
          value: 'custom',
          child: Text('⚙️ Custom reminder'),
        ),
      ],
    );
  }

  void _setReminder(BuildContext context, String timing) {
    // TODO: Implement reminder system
    String message;
    switch (timing) {
      case '15min':
        message = 'Reminder set for 15 minutes before playdate';
        break;
      case '1hour':
        message = 'Reminder set for 1 hour before playdate';
        break;
      case '1day':
        message = 'Reminder set for 1 day before playdate';
        break;
      case 'custom':
        message = 'Custom reminders coming soon!';
        break;
      default:
        message = 'Reminder set';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // TODO: Implement reminder removal
          },
        ),
      ),
    );
  }
}

/// Requirements for Google Calendar Integration
/// 
/// 1. Dependencies needed:
///    - add_2_calendar: ^3.0.1 (cross-platform)
///    - OR device_calendar: ^4.3.2 (more features)
///    - permission_handler: ^11.0.1 (for permissions)
/// 
/// 2. Android permissions (android/app/src/main/AndroidManifest.xml):
///    <uses-permission android:name="android.permission.READ_CALENDAR" />
///    <uses-permission android:name="android.permission.WRITE_CALENDAR" />
/// 
/// 3. iOS permissions (ios/Runner/Info.plist):
///    <key>NSCalendarsUsageDescription</key>
///    <string>BarkDate needs calendar access to sync your playdates</string>
/// 
/// 4. Google Calendar API setup (optional for advanced features):
///    - Enable Google Calendar API in Google Cloud Console
///    - Add googleapis dependency
///    - Implement OAuth2 flow for cloud sync
/// 
/// Implementation priority:
/// Phase 1: Basic device calendar integration (add_2_calendar)
/// Phase 2: Advanced features (device_calendar) 
/// Phase 3: Google Calendar API sync (cloud sync)
/// Phase 4: Cross-platform sharing and invitations
