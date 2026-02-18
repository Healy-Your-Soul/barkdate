import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/notification_service.dart';

/// Simplified playdate service that works with basic schema
class SimplifiedPlaydateService {
  /// Create a simple playdate without requiring extra tables
  static Future<String?> createSimplePlaydate({
    required String organizerId,
    required String organizerDogId,
    required String inviteeId,
    required String inviteeDogId,
    required String title,
    required String location,
    required DateTime scheduledAt,
    String? description,
    String? message,
    int durationMinutes = 60,
    double? latitude,
    double? longitude,
  }) async {
    try {
      debugPrint('=== CREATING SIMPLE PLAYDATE ===');
      debugPrint('Organizer: $organizerId, Dog: $organizerDogId');
      debugPrint('Invitee: $inviteeId, Dog: $inviteeDogId');
      debugPrint('Location: $location, Time: $scheduledAt');

      // Create playdate with only basic fields that definitely exist
      final Map<String, dynamic> playdateData = {
        'organizer_id': organizerId,
        'participant_id': inviteeId,
        'title': title,
        'location': location,
        'scheduled_at': scheduledAt.toIso8601String(),
        'status': 'pending',
      };

      // Add optional fields only if provided
      if (description != null) playdateData['description'] = description;
      if (latitude != null) playdateData['latitude'] = latitude;
      if (longitude != null) playdateData['longitude'] = longitude;
      if (durationMinutes != 60)
        playdateData['duration_minutes'] = durationMinutes;

      final playdateResult = await SupabaseConfig.client
          .from('playdates')
          .insert(playdateData)
          .select('id')
          .single();

      final playdateId = playdateResult['id'];
      debugPrint('Created playdate with ID: $playdateId');

      // Get dog names for notification
      try {
        final organizerDog = await SupabaseConfig.client
            .from('dogs')
            .select('name')
            .eq('id', organizerDogId)
            .single();

        final inviteeDog = await SupabaseConfig.client
            .from('dogs')
            .select('name')
            .eq('id', inviteeDogId)
            .single();

        // Create notification using the existing service
        await NotificationService.createNotification(
          userId: inviteeId,
          type: 'playdate_request',
          actionType: 'playdate_invited',
          title: 'New Playdate Invitation! 🐕',
          body:
              '${organizerDog['name']} invited ${inviteeDog['name']} for a playdate at $location',
          relatedId: playdateId,
          metadata: {
            'playdate_id': playdateId,
            'organizer_id': organizerId,
            'organizer_dog_id': organizerDogId,
            'organizer_dog_name': organizerDog['name'],
            'invitee_dog_name': inviteeDog['name'],
            'title': title,
            'location': location,
            'scheduled_at': scheduledAt.toIso8601String(),
            'message': message,
          },
        );
      } catch (e) {
        debugPrint('Could not send notification: $e');
        // Continue anyway - playdate is still created
      }

      return playdateId;
    } catch (e) {
      debugPrint('Error creating playdate: $e');
      return null;
    }
  }

  /// Get upcoming playdates for a user
  static Future<List<Map<String, dynamic>>> getUpcomingPlaydates(
      String userId) async {
    try {
      final now = DateTime.now();
      final playdates = await SupabaseConfig.client
          .from('playdates')
          .select('*')
          .or('organizer_id.eq.$userId,participant_id.eq.$userId')
          .gte('scheduled_at', now.toIso8601String())
          .order('scheduled_at', ascending: true);

      return playdates;
    } catch (e) {
      debugPrint('Error getting upcoming playdates: $e');
      return [];
    }
  }

  /// Get past playdates for a user
  static Future<List<Map<String, dynamic>>> getPastPlaydates(
      String userId) async {
    try {
      final now = DateTime.now();
      final playdates = await SupabaseConfig.client
          .from('playdates')
          .select('*')
          .or('organizer_id.eq.$userId,participant_id.eq.$userId')
          .lt('scheduled_at', now.toIso8601String())
          .order('scheduled_at', ascending: false);

      return playdates;
    } catch (e) {
      debugPrint('Error getting past playdates: $e');
      return [];
    }
  }

  /// Update playdate status
  static Future<bool> updatePlaydateStatus({
    required String playdateId,
    required String status,
  }) async {
    try {
      await SupabaseConfig.client
          .from('playdates')
          .update({'status': status}).eq('id', playdateId);

      debugPrint('Updated playdate $playdateId status to $status');
      return true;
    } catch (e) {
      debugPrint('Error updating playdate status: $e');
      return false;
    }
  }

  /// Cancel a playdate
  static Future<bool> cancelPlaydate({
    required String playdateId,
    String? reason,
  }) async {
    try {
      final updateData = {
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (reason != null) {
        updateData['cancellation_reason'] = reason;
      }

      await SupabaseConfig.client
          .from('playdates')
          .update(updateData)
          .eq('id', playdateId);

      debugPrint('Cancelled playdate $playdateId');
      return true;
    } catch (e) {
      debugPrint('Error cancelling playdate: $e');
      return false;
    }
  }
}
