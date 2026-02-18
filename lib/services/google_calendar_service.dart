import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Google Calendar Integration Service
/// Allows creating calendar events for playdates
class GoogleCalendarService {
  static const String _baseUrl = 'https://www.googleapis.com/calendar/v3';

  /// Create a calendar event for a playdate
  static Future<bool> createPlaydateEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    List<String> attendeeEmails = const [],
  }) async {
    try {
      // TODO: Implement Supabase + Google OAuth for calendar access
      debugPrint('❌ Google Calendar integration temporarily disabled');
      return false;

      /*
      final event = {
        'summary': title,
        'description': description,
        'location': location,
        'start': {
          'dateTime': startTime.toIso8601String(),
          'timeZone': DateTime.now().timeZoneName,
        },
        'end': {
          'dateTime': endTime.toIso8601String(),
          'timeZone': DateTime.now().timeZoneName,
        },
        'attendees': attendeeEmails.map((email) => {'email': email}).toList(),
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 30},
            {'method': 'popup', 'minutes': 10},
          ],
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/calendars/primary/events'),
        headers: {
          'Authorization': 'Bearer \$accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(event),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Calendar event created successfully');
        return true;
      } else {
        debugPrint('❌ Failed to create calendar event: \${response.statusCode}');
        debugPrint('Response: \${response.body}');
        return false;
      }
      */
    } catch (e) {
      debugPrint('❌ Error creating calendar event: $e');
      return false;
    }
  }

  /// Get upcoming events from calendar
  static Future<List<Map<String, dynamic>>> getUpcomingEvents({
    int maxResults = 10,
  }) async {
    try {
      // TODO: Implement Supabase + Google OAuth for calendar access
      debugPrint('❌ Google Calendar integration temporarily disabled');
      return [];

      /*
      final now = DateTime.now().toIso8601String();
      final response = await http.get(
        Uri.parse('$_baseUrl/calendars/primary/events'
            '?timeMin=$now'
            '&maxResults=$maxResults'
            '&singleEvents=true'
            '&orderBy=startTime'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = (data['items'] as List)
            .map((event) => event as Map<String, dynamic>)
            .toList();
        
        debugPrint('✅ Retrieved ${events.length} calendar events');
        return events;
      } else {
        debugPrint('❌ Failed to get calendar events: ${response.statusCode}');
        return [];
      }
      */
    } catch (e) {
      debugPrint('❌ Error getting calendar events: $e');
      return [];
    }
  }

  /// Check if user has conflicting events at the given time
  static Future<bool> hasConflictingEvents({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final events = await getUpcomingEvents(maxResults: 100);

      for (final event in events) {
        final eventStart = DateTime.parse(
            event['start']['dateTime'] ?? event['start']['date']);
        final eventEnd =
            DateTime.parse(event['end']['dateTime'] ?? event['end']['date']);

        // Check for overlap
        if (startTime.isBefore(eventEnd) && endTime.isAfter(eventStart)) {
          debugPrint('⚠️ Conflicting event found: ${event['summary']}');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking for conflicts: $e');
      return false; // Assume no conflicts if we can't check
    }
  }
}
