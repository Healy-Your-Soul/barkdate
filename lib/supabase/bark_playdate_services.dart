import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/notification_service.dart';

/// Enhanced services for bark notifications and playdate management
/// Part of the BarkDate sprint to implement social interaction features

// =============================================================================
// BARK NOTIFICATION SERVICE
// =============================================================================

class BarkNotificationService {
  /// Send a bark notification to another user
  /// This is like a "hello" or "I'm interested" without commitment
  static Future<bool> sendBark({
    required String fromUserId,
    required String toUserId,
    required String fromDogId,
    required String toDogId,
  }) async {
    try {
      debugPrint('=== SENDING BARK ===');
      debugPrint('From User: $fromUserId, Dog: $fromDogId');
      debugPrint('To User: $toUserId, Dog: $toDogId');

      // Check if bark already exists or was sent recently
      final existingMatch = await SupabaseConfig.client
          .from('matches')
          .select('id, bark_count, last_bark_at')
          .eq('user_id', fromUserId)
          .eq('target_user_id', toUserId)
          .eq('dog_id', fromDogId)
          .eq('target_dog_id', toDogId)
          .maybeSingle();

      final now = DateTime.now();
      
      if (existingMatch != null) {
        // Check if last bark was within 24 hours (spam prevention)
        if (existingMatch['last_bark_at'] != null) {
          final lastBark = DateTime.parse(existingMatch['last_bark_at']);
          final hoursSinceLastBark = now.difference(lastBark).inHours;
          
          if (hoursSinceLastBark < 24) {
            debugPrint('Bark rejected: Too soon since last bark ($hoursSinceLastBark hours ago)');
            return false;
          }
        }

        // Update existing match with new bark
        await SupabaseConfig.client
            .from('matches')
            .update({
              'bark_count': (existingMatch['bark_count'] ?? 0) + 1,
              'last_bark_at': now.toIso8601String(),
              'action': 'bark', // Ensure it's marked as bark
            })
            .eq('id', existingMatch['id']);
            
        debugPrint('Updated existing match with new bark');
      } else {
        // Create new match record
        await SupabaseConfig.client
            .from('matches')
            .insert({
              'user_id': fromUserId,
              'target_user_id': toUserId,
              'dog_id': fromDogId,
              'target_dog_id': toDogId,
              'action': 'bark',
              'bark_count': 1,
              'last_bark_at': now.toIso8601String(),
              'is_mutual': false, // Will be updated if target user barks back
            });
            
        debugPrint('Created new match record for bark');
      }

      // Get dog names for notification
      final fromDog = await SupabaseConfig.client
          .from('dogs')
          .select('name')
          .eq('id', fromDogId)
          .single();

      final toDog = await SupabaseConfig.client
          .from('dogs')
          .select('name')
          .eq('id', toDogId)
          .single();

      // Create notification for the target user
      await NotificationService.createNotification(
        userId: toUserId,
        type: 'bark',
        actionType: 'bark_received',
        title: '${fromDog['name']} barked at ${toDog['name']}! 🐕',
        body: 'Someone is interested in meeting your pup!',
        relatedId: fromDogId,
        metadata: {
          'from_user_id': fromUserId,
          'from_dog_id': fromDogId,
          'from_dog_name': fromDog['name'],
          'to_dog_id': toDogId,
          'to_dog_name': toDog['name'],
        },
      );

      // Check if this creates a mutual bark (both dogs barked at each other)
      final mutualMatch = await SupabaseConfig.client
          .from('matches')
          .select('id')
          .eq('user_id', toUserId)
          .eq('target_user_id', fromUserId)
          .eq('dog_id', toDogId)
          .eq('target_dog_id', fromDogId)
          .eq('action', 'bark')
          .maybeSingle();

      if (mutualMatch != null) {
        // Update both matches to indicate mutual interest
        await SupabaseConfig.client
            .from('matches')
            .update({'is_mutual': true})
            .inFilter('id', [mutualMatch['id']]);
            
        // Create mutual match notification
        await NotificationService.createNotification(
          userId: fromUserId,
          type: 'match',
          actionType: 'mutual_bark',
          title: 'It\'s a match! 🎉',
          body: '${fromDog['name']} and ${toDog['name']} both barked at each other!',
          relatedId: toUserId,
          metadata: {
            'match_type': 'mutual_bark',
            'other_user_id': toUserId,
            'other_dog_id': toDogId,
            'other_dog_name': toDog['name'],
          },
        );

        await NotificationService.createNotification(
          userId: toUserId,
          type: 'match',
          actionType: 'mutual_bark',
          title: 'It\'s a match! 🎉',
          body: '${toDog['name']} and ${fromDog['name']} both barked at each other!',
          relatedId: fromUserId,
          metadata: {
            'match_type': 'mutual_bark',
            'other_user_id': fromUserId,
            'other_dog_id': fromDogId,
            'other_dog_name': fromDog['name'],
          },
        );
        
        debugPrint('Created mutual bark match! 🎉');
      }

      debugPrint('Bark sent successfully!');
      return true;
      
    } catch (e) {
      debugPrint('Error sending bark: $e');
      return false;
    }
  }

  /// Get bark history for a user (who they barked at, who barked at them)
  static Future<List<Map<String, dynamic>>> getBarkHistory(String userId) async {
    try {
      final history = await SupabaseConfig.client
          .from('matches')
          .select('''
            *,
            target_dog:dogs!matches_target_dog_id_fkey(name, main_photo_url),
            my_dog:dogs!matches_dog_id_fkey(name, main_photo_url),
            target_user:users!matches_target_user_id_fkey(name, avatar_url)
          ''')
          .or('user_id.eq.$userId,target_user_id.eq.$userId')
          .eq('action', 'bark')
          .order('last_bark_at', ascending: false);

      return history;
    } catch (e) {
      debugPrint('Error getting bark history: $e');
      return [];
    }
  }
}

// =============================================================================
// PLAYDATE REQUEST SERVICE
// =============================================================================

class PlaydateRequestService {
  /// Create a new playdate request
  static Future<String?> createPlaydateRequest({
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
      debugPrint('=== CREATING PLAYDATE REQUEST ===');
      debugPrint('Organizer: $organizerId, Dog: $organizerDogId');
      debugPrint('Invitee: $inviteeId, Dog: $inviteeDogId');
      debugPrint('Location: $location, Time: $scheduledAt');

      // First create the playdate
      final playdateResult = await SupabaseConfig.client
          .from('playdates')
          .insert({
            'organizer_id': organizerId,
            'participant_id': inviteeId,
            'title': title,
            'description': description,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'scheduled_at': scheduledAt.toIso8601String(),
            'duration_minutes': durationMinutes,
            'status': 'pending',
          })
          .select('id')
          .single();

      final playdateId = playdateResult['id'];
      debugPrint('Created playdate with ID: $playdateId');

      // Add organizer as participant
      await SupabaseConfig.client
          .from('playdate_participants')
          .insert({
            'playdate_id': playdateId,
            'user_id': organizerId,
            'dog_id': organizerDogId,
          });

      // Create the playdate request for the invitee
      await SupabaseConfig.client
          .from('playdate_requests')
          .insert({
            'playdate_id': playdateId,
            'requester_id': organizerId,
            'invitee_id': inviteeId,
            'invitee_dog_id': inviteeDogId,
            'status': 'pending',
            'message': message,
          });

      // Get dog names for notification
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

      // Create notification for invitee
      await NotificationService.createNotification(
        userId: inviteeId,
        type: 'playdate_request',
        actionType: 'playdate_invited',
        title: 'New Playdate Invitation! 🐕',
        body: '${organizerDog['name']} invited ${inviteeDog['name']} for a playdate at $location',
        relatedId: playdateId,
        metadata: {
          'playdate_id': playdateId,
          'organizer_id': organizerId,
          'organizer_dog_id': organizerDogId,
          'organizer_dog_name': organizerDog['name'],
          'title': title,
          'location': location,
          'scheduled_at': scheduledAt.toIso8601String(),
        },
      );

      debugPrint('Playdate request created successfully!');
      return playdateId;

    } catch (e) {
      debugPrint('Error creating playdate request: $e');
      debugPrint('Error type: ${e.runtimeType} - details: ${e.toString()}');
      return null;
    }
  }

  /// Respond to a playdate request (accept, decline, counter-propose)
  static Future<bool> respondToPlaydateRequest({
    required String requestId,
    required String userId,
    required String response, // 'accepted', 'declined', 'counter_proposed'
    String? message,
    Map<String, dynamic>? counterProposal,
  }) async {
    try {
      debugPrint('=== RESPONDING TO PLAYDATE REQUEST ===');
      debugPrint('Request ID: $requestId');
      debugPrint('Response: $response');

      final now = DateTime.now();

      // Update the request
      final updateData = {
        'status': response,
        'responded_at': now.toIso8601String(),
      };

      if (message != null) updateData['message'] = message;
      if (counterProposal != null) updateData['counter_proposal'] = counterProposal.toString();

      await SupabaseConfig.client
          .from('playdate_requests')
          .update(updateData)
          .eq('id', requestId);

      // Get request details for notification
      final request = await SupabaseConfig.client
          .from('playdate_requests')
          .select('''
            *,
            playdate:playdates(*),
            requester:users!playdate_requests_requester_id_fkey(name),
            invitee:users!playdate_requests_invitee_id_fkey(name),
            invitee_dog:dogs!playdate_requests_invitee_dog_id_fkey(name)
          ''')
          .eq('id', requestId)
          .single();

      if (response == 'accepted') {
        // Update playdate to include participant and set status to confirmed
        await SupabaseConfig.client
            .from('playdates')
            .update({
              'participant_id': request['invitee_id'], // Set the main participant
              'status': 'confirmed'
            })
            .eq('id', request['playdate_id']);

        // Add invitee as participant (for many-to-many relationships if needed later)
        await SupabaseConfig.client
            .from('playdate_participants')
            .insert({
              'playdate_id': request['playdate_id'],
              'user_id': request['invitee_id'],
              'dog_id': request['invitee_dog_id'],
            });

        // Notify organizer
        await NotificationService.createNotification(
          userId: request['requester_id'],
          type: 'playdate',
          actionType: 'playdate_accepted',
          title: 'Playdate Accepted! 🎉',
          body: '${request['invitee']['name']} accepted your playdate invitation!',
          relatedId: request['playdate_id'],
          metadata: {
            'playdate_id': request['playdate_id'],
            'responder_name': request['invitee']['name'],
            'dog_name': request['invitee_dog']['name'],
          },
        );

      } else if (response == 'declined') {
        // Update playdate status to cancelled
        await SupabaseConfig.client
            .from('playdates')
            .update({'status': 'cancelled'})
            .eq('id', request['playdate_id']);

        // Notify organizer
        await NotificationService.createNotification(
          userId: request['requester_id'],
          type: 'playdate',
          actionType: 'playdate_declined',
          title: 'Playdate Declined',
          body: '${request['invitee']['name']} declined your playdate invitation',
          relatedId: request['playdate_id'],
          metadata: {
            'playdate_id': request['playdate_id'],
            'responder_name': request['invitee']['name'],
            'message': message,
          },
        );

      } else if (response == 'counter_proposed') {
        // Notify organizer about counter-proposal
        await NotificationService.createNotification(
          userId: request['requester_id'],
          type: 'playdate',
          actionType: 'playdate_counter_proposed',
          title: 'Playdate Counter-Proposal',
          body: '${request['invitee']['name']} suggested changes to your playdate',
          relatedId: request['playdate_id'],
          metadata: {
            'playdate_id': request['playdate_id'],
            'responder_name': request['invitee']['name'],
            'counter_proposal': counterProposal,
            'message': message,
          },
        );
      }

      debugPrint('Playdate request response processed successfully!');
      return true;

    } catch (e) {
      debugPrint('Error responding to playdate request: $e');
      debugPrint('Error type: ${e.runtimeType} - details: ${e.toString()}');
      return false;
    }
  }

  /// Get pending playdate requests for a user
  static Future<List<Map<String, dynamic>>> getPendingRequests(String userId) async {
    try {
      // Try the RPC function first (if available after SQL update)
      try {
        final rpcResult = await SupabaseConfig.client
            .rpc('get_pending_playdate_requests', params: {'user_id_param': userId});
        
        if (rpcResult != null && rpcResult is List && rpcResult.isNotEmpty) {
          return List<Map<String, dynamic>>.from(rpcResult);
        }
      } catch (rpcError) {
        debugPrint('RPC function not available, falling back to basic query: $rpcError');
      }

      // Fallback to simple query without complex joins
      final requests = await SupabaseConfig.client
          .from('playdate_requests')
          .select('*')
          .eq('invitee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      // Manually fetch related data for each request
      final enrichedRequests = <Map<String, dynamic>>[];
      
      for (final request in requests) {
        final enrichedRequest = Map<String, dynamic>.from(request);
        
        // Get playdate details
        try {
          final playdate = await SupabaseConfig.client
              .from('playdates')
              .select('*')
              .eq('id', request['playdate_id'])
              .maybeSingle();
          enrichedRequest['playdate'] = playdate;
        } catch (e) {
          debugPrint('Error fetching playdate: $e');
        }

        // Get requester details
        try {
          final requester = await SupabaseConfig.client
              .from('users')
              .select('name, avatar_url')
              .eq('id', request['requester_id'])
              .maybeSingle();
          enrichedRequest['requester'] = requester;
        } catch (e) {
          debugPrint('Error fetching requester: $e');
        }

        // Get invitee dog details
        try {
          final inviteeDog = await SupabaseConfig.client
              .from('dogs')
              .select('name, main_photo_url, breed')
              .eq('id', request['invitee_dog_id'])
              .maybeSingle();
          enrichedRequest['invitee_dog'] = inviteeDog;
        } catch (e) {
          debugPrint('Error fetching invitee dog: $e');
        }

        enrichedRequests.add(enrichedRequest);
      }

      return enrichedRequests;
    } catch (e) {
      debugPrint('Error getting pending requests: $e');
      return [];
    }
  }

  /// Get sent playdate requests for a user (where user is the requester)
  static Future<List<Map<String, dynamic>>> getSentRequests(String userId) async {
    try {
      debugPrint('=== GETTING SENT REQUESTS FOR USER: $userId ===');
      
      // Get requests where user is the requester
      final requests = await SupabaseConfig.client
          .from('playdate_requests')
          .select('*')
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      debugPrint('Found ${requests.length} sent requests');

      // Manually fetch related data for each request
      final enrichedRequests = <Map<String, dynamic>>[];
      
      for (final request in requests) {
        final enrichedRequest = Map<String, dynamic>.from(request);
        
        // Get playdate details
        try {
          final playdate = await SupabaseConfig.client
              .from('playdates')
              .select('*')
              .eq('id', request['playdate_id'])
              .single();
          enrichedRequest['playdate'] = playdate;
        } catch (e) {
          debugPrint('Error fetching playdate: $e');
          enrichedRequest['playdate'] = null;
        }

        // Get invitee (recipient) details
        try {
          final invitee = await SupabaseConfig.client
              .from('users')
              .select('id, name, avatar_url')
              .eq('id', request['invitee_id'])
              .single();
          enrichedRequest['invitee'] = invitee;
        } catch (e) {
          debugPrint('Error fetching invitee: $e');
          enrichedRequest['invitee'] = null;
        }

        // Get invitee dog details
        try {
          final inviteeDog = await SupabaseConfig.client
              .from('dogs')
              .select('id, name, breed, main_photo_url')
              .eq('id', request['invitee_dog_id'])
              .single();
          enrichedRequest['invitee_dog'] = inviteeDog;
        } catch (e) {
          debugPrint('Error fetching invitee dog: $e');
          enrichedRequest['invitee_dog'] = null;
        }

        enrichedRequests.add(enrichedRequest);
      }

      debugPrint('Returning ${enrichedRequests.length} enriched sent requests');
      return enrichedRequests;

    } catch (e) {
      debugPrint('Error getting sent requests: $e');
      return [];
    }
  }

  /// Cancel a playdate request (for requester to withdraw)
  static Future<bool> cancelRequest(String requestId) async {
    try {
      debugPrint('=== CANCELLING PLAYDATE REQUEST ===');
      debugPrint('Request ID: $requestId');

      // Update request status to cancelled
      await SupabaseConfig.client
          .from('playdate_requests')
          .update({
            'status': 'cancelled',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // Get request details to update playdate
      final request = await SupabaseConfig.client
          .from('playdate_requests')
          .select('playdate_id, invitee_id')
          .eq('id', requestId)
          .single();

      // Update associated playdate status to cancelled
      await SupabaseConfig.client
          .from('playdates')
          .update({'status': 'cancelled'})
          .eq('id', request['playdate_id']);

      debugPrint('Playdate request cancelled successfully!');
      return true;

    } catch (e) {
      debugPrint('Error cancelling playdate request: $e');
      return false;
    }
  }

  /// Update playdate details (time, location, etc.)
  static Future<bool> updatePlaydateDetails({
    required String playdateId,
    required String userId,
    String? title,
    String? location,
    DateTime? scheduledAt,
    String? description,
    int? durationMinutes,
    double? latitude,
    double? longitude,
  }) async {
    try {
      debugPrint('=== UPDATING PLAYDATE DETAILS ===');
      debugPrint('Playdate ID: $playdateId');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateData['title'] = title;
      if (location != null) updateData['location'] = location;
      if (scheduledAt != null) updateData['scheduled_at'] = scheduledAt.toIso8601String();
      if (description != null) updateData['description'] = description;
      if (durationMinutes != null) updateData['duration_minutes'] = durationMinutes;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;

      await SupabaseConfig.client
          .from('playdates')
          .update(updateData)
          .eq('id', playdateId);

      // Get all participants to notify about the update
      final participants = await SupabaseConfig.client
          .from('playdate_participants')
          .select('user_id')
          .eq('playdate_id', playdateId)
          .neq('user_id', userId); // Don't notify the user who made the change

      // Notify all other participants
      for (final participant in participants) {
        await NotificationService.createNotification(
          userId: participant['user_id'],
          type: 'playdate',
          actionType: 'playdate_updated',
          title: 'Playdate Updated',
          body: 'The organizer made changes to your upcoming playdate',
          relatedId: playdateId,
          metadata: {
            'playdate_id': playdateId,
            'updated_by': userId,
            'changes': updateData,
          },
        );
      }

      debugPrint('Playdate updated successfully!');
      return true;

    } catch (e) {
      debugPrint('Error updating playdate: $e');
      return false;
    }
  }
}

// =============================================================================
// PLAYDATE MANAGEMENT SERVICE (participants, cancel, reschedule)
// =============================================================================

class PlaydateManagementService {
  /// Add a participant (user + dog) to a playdate and notify the added user
  static Future<bool> addParticipant({
    required String playdateId,
    required String userId,
    required String dogId,
    required String addedByUserId,
  }) async {
    try {
      // Insert participant (ignore if duplicate by relying on DB unique constraints if present)
      await SupabaseConfig.client
          .from('playdate_participants')
          .insert({
            'playdate_id': playdateId,
            'user_id': userId,
            'dog_id': dogId,
          });

      // Notify the added user
      await NotificationService.createNotification(
        userId: userId,
        type: 'playdate',
        actionType: 'participant_added',
        title: 'You were added to a playdate',
        body: 'You have been added to an upcoming playdate.',
        relatedId: playdateId,
        metadata: {
          'playdate_id': playdateId,
          'added_by': addedByUserId,
          'user_id': userId,
          'dog_id': dogId,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error adding participant: $e');
      return false;
    }
  }

  /// Remove a participant from a playdate and notify the organizer
  static Future<bool> removeParticipant({
    required String playdateId,
    required String userId,
    required String removedByUserId,
  }) async {
    try {
      // Remove participant row
      await SupabaseConfig.client
          .from('playdate_participants')
          .delete()
          .eq('playdate_id', playdateId)
          .eq('user_id', userId);

      // Fetch organizer to notify
      final playdate = await SupabaseConfig.client
          .from('playdates')
          .select('organizer_id')
          .eq('id', playdateId)
          .single();

      final organizerId = playdate['organizer_id'] as String;

      await NotificationService.createNotification(
        userId: organizerId,
        type: 'playdate',
        actionType: 'participant_removed',
        title: 'Participant removed',
        body: 'A participant was removed from your playdate.',
        relatedId: playdateId,
        metadata: {
          'playdate_id': playdateId,
          'removed_user_id': userId,
          'removed_by': removedByUserId,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error removing participant: $e');
      return false;
    }
  }

  /// Cancel a playdate and notify all participants
  static Future<bool> cancelPlaydate({
    required String playdateId,
    required String cancelledByUserId,
    String? reason,
  }) async {
    try {
      // Update playdate status
      await SupabaseConfig.client
          .from('playdates')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', playdateId);

      // Get all participants (including organizer) to notify
      final participantRows = await SupabaseConfig.client
          .from('playdate_participants')
          .select('user_id')
          .eq('playdate_id', playdateId);

      for (final p in participantRows) {
        await NotificationService.createNotification(
          userId: p['user_id'] as String,
          type: 'playdate',
          actionType: 'playdate_cancelled',
          title: 'Playdate cancelled',
          body: reason == null ? 'A playdate you joined was cancelled.' : 'Cancelled: $reason',
          relatedId: playdateId,
          metadata: {
            'playdate_id': playdateId,
            'cancelled_by': cancelledByUserId,
            if (reason != null) 'reason': reason,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error cancelling playdate: $e');
      return false;
    }
  }

  /// Reschedule a playdate (time and/or location). Notifies other participants as updated.
  static Future<bool> reschedulePlaydate({
    required String playdateId,
    required String updatedByUserId,
    DateTime? newScheduledAt,
    String? newLocation,
    String? newDescription,
    int? newDurationMinutes,
    double? newLatitude,
    double? newLongitude,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newScheduledAt != null) updateData['scheduled_at'] = newScheduledAt.toIso8601String();
      if (newLocation != null) updateData['location'] = newLocation;
      if (newDescription != null) updateData['description'] = newDescription;
      if (newDurationMinutes != null) updateData['duration_minutes'] = newDurationMinutes;
      if (newLatitude != null) updateData['latitude'] = newLatitude;
      if (newLongitude != null) updateData['longitude'] = newLongitude;

      await SupabaseConfig.client
          .from('playdates')
          .update(updateData)
          .eq('id', playdateId);

      // Notify all other participants
      final participants = await SupabaseConfig.client
          .from('playdate_participants')
          .select('user_id')
          .eq('playdate_id', playdateId)
          .neq('user_id', updatedByUserId);

      for (final participant in participants) {
        await NotificationService.createNotification(
          userId: participant['user_id'] as String,
          type: 'playdate',
          actionType: 'playdate_updated',
          title: 'Playdate rescheduled',
          body: 'Details for your playdate were updated.',
          relatedId: playdateId,
          metadata: {
            'playdate_id': playdateId,
            'updated_by': updatedByUserId,
            'changes': updateData,
          },
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error rescheduling playdate: $e');
      return false;
    }
  }
}

// =============================================================================
// PLAYDATE RECAP SERVICE
// =============================================================================

class PlaydateRecapService {
  /// Create a recap for a completed playdate
  static Future<bool> createRecap({
    required String playdateId,
    required String userId,
    required String dogId,
    required int experienceRating,
    required int locationRating,
    String? recapText,
    List<String>? photos,
    bool shareToFeed = false,
  }) async {
    try {
      debugPrint('=== CREATING PLAYDATE RECAP ===');
      debugPrint('Playdate: $playdateId, User: $userId, Dog: $dogId');

      String? postId;

      // If sharing to feed, create a social post first
      if (shareToFeed && recapText != null) {
        final postResult = await SupabaseConfig.client
            .from('posts')
            .insert({
              'user_id': userId,
              'dog_id': dogId,
              'content': recapText,
              'image_urls': photos ?? [],
              'is_public': true,
            })
            .select('id')
            .single();

        postId = postResult['id'];
        debugPrint('Created social post: $postId');
      }

      // Create the recap
      await SupabaseConfig.client
          .from('playdate_recaps')
          .insert({
            'playdate_id': playdateId,
            'user_id': userId,
            'dog_id': dogId,
            'experience_rating': experienceRating,
            'location_rating': locationRating,
            'recap_text': recapText,
            'photos': photos ?? [],
            'shared_to_feed': shareToFeed,
            'post_id': postId,
          });

      debugPrint('Playdate recap created successfully!');
      return true;

    } catch (e) {
      debugPrint('Error creating playdate recap: $e');
      return false;
    }
  }

  /// Get recaps for a playdate
  static Future<List<Map<String, dynamic>>> getPlaydateRecaps(String playdateId) async {
    try {
      final recaps = await SupabaseConfig.client
          .from('playdate_recaps')
          .select('''
            *,
            user:users(name, avatar_url),
            dog:dogs(name, main_photo_url)
          ''')
          .eq('playdate_id', playdateId)
          .order('created_at', ascending: false);

      return recaps;
    } catch (e) {
      debugPrint('Error getting playdate recaps: $e');
      return [];
    }
  }
}

// =============================================================================
// DOG FRIENDSHIP SERVICE
// =============================================================================

class DogFriendshipService {
  /// Get friends for a dog
  static Future<List<Map<String, dynamic>>> getDogFriends(String dogId) async {
    try {
      final friendships = await SupabaseConfig.client
          .from('dog_friendships')
          .select('''
            *,
            friend_dog:dogs(
              id, name, main_photo_url, breed, age,
              user:users(id, name, avatar_url)
            )
          ''')
          .or('dog1_id.eq.$dogId,dog2_id.eq.$dogId')
          .order('friendship_level', ascending: false)
          .order('created_at', ascending: false);

      // Map the friend dog data correctly
      return friendships.map((friendship) {
        final friendDogId = friendship['dog1_id'] == dogId 
            ? friendship['dog2_id'] 
            : friendship['dog1_id'];
        
        return {
          ...friendship,
          'friend_dog_id': friendDogId,
        };
      }).toList();

    } catch (e) {
      debugPrint('Error getting dog friends: $e');
      return [];
    }
  }

  /// Create or update friendship between two dogs
  static Future<bool> createFriendship({
    required String dog1Id,
    required String dog2Id,
    String? playdateId,
    String friendshipLevel = 'acquaintance',
  }) async {
    try {
      // Ensure consistent ordering (smaller ID first)
      final sortedIds = [dog1Id, dog2Id]..sort();
      
      await SupabaseConfig.client
          .from('dog_friendships')
          .insert({
            'dog1_id': sortedIds[0],
            'dog2_id': sortedIds[1],
            'formed_through_playdate_id': playdateId,
            'friendship_level': friendshipLevel,
          });

      return true;
    } catch (e) {
      debugPrint('Error creating dog friendship: $e');
      return false;
    }
  }

  /// Get all requests for a user (all statuses)
  static Future<List<Map<String, dynamic>>> getAllRequests(String userId, String role) async {
    try {
      String columnName = role == 'invitee' ? 'invitee_id' : 'requester_id';
      
      final requests = await SupabaseConfig.client
          .from('playdate_requests')
          .select('*')
          .eq(columnName, userId)
          .order('created_at', ascending: false);

      // Manually fetch related data for each request
      final enrichedRequests = <Map<String, dynamic>>[];
      
      for (final request in requests) {
        final enrichedRequest = Map<String, dynamic>.from(request);
        
        // Get playdate details
        try {
          final playdate = await SupabaseConfig.client
              .from('playdates')
              .select('*')
              .eq('id', request['playdate_id'])
              .maybeSingle();
          
          enrichedRequest['playdate'] = playdate;
        } catch (e) {
          debugPrint('Error fetching playdate for request ${request['id']}: $e');
        }

        // Get requester details
        try {
          final requester = await SupabaseConfig.client
              .from('profiles')
              .select('id, name, avatar_url')
              .eq('id', request['requester_id'])
              .maybeSingle();
          
          enrichedRequest['requester'] = requester;
        } catch (e) {
          debugPrint('Error fetching requester for request ${request['id']}: $e');
        }

        // Get invitee details  
        try {
          final invitee = await SupabaseConfig.client
              .from('profiles')
              .select('id, name, avatar_url')
              .eq('id', request['invitee_id'])
              .maybeSingle();
          
          enrichedRequest['invitee'] = invitee;
        } catch (e) {
          debugPrint('Error fetching invitee for request ${request['id']}: $e');
        }

        // Get invitee dog details
        try {
          final inviteeDog = await SupabaseConfig.client
              .from('dogs')
              .select('*')
              .eq('id', request['invitee_dog_id'])
              .maybeSingle();
          
          enrichedRequest['invitee_dog'] = inviteeDog;
        } catch (e) {
          debugPrint('Error fetching invitee dog for request ${request['id']}: $e');
        }

        // Get requester dog details
        try {
          final requesterDog = await SupabaseConfig.client
              .from('dogs')
              .select('*')
              .eq('id', request['requester_dog_id'])
              .maybeSingle();
          
          enrichedRequest['requester_dog'] = requesterDog;
        } catch (e) {
          debugPrint('Error fetching requester dog for request ${request['id']}: $e');
        }

        enrichedRequests.add(enrichedRequest);
      }

      debugPrint('Returning ${enrichedRequests.length} enriched $role requests');
      return enrichedRequests;

    } catch (e) {
      debugPrint('Error getting $role requests for user $userId: $e');
      return [];
    }
  }
}
