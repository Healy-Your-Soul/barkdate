import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/playdate.dart';
import '../models/enhanced_dog.dart';

class PlaydateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user's playdates (as organizer or participant)
  static Future<List<Playdate>> getUserPlaydates(String userId) async {
    try {
      // Get playdates where user is organizer or participant
      final response = await _supabase
          .from('playdates')
          .select('''
            *,
            participants:playdate_participants(
              id,
              user_id,
              dog_id,
              joined_at,
              is_organizer,
              user:users(id, name, avatar_url),
              dog:dogs(id, name, main_photo_url)
            )
          ''')
          .or('organizer_id.eq.$userId,id.in.(${await _getUserParticipantPlaydateIds(userId)})')
          .order('scheduled_at', ascending: true);

      final List<dynamic> data = response;
      return data.map((item) => _parsePlaydateFromResponse(item)).toList();
    } catch (e) {
      debugPrint('Error fetching user playdates: $e');
      return [];
    }
  }

  // Get playdate requests for current user
  static Future<List<PlaydateRequest>> getUserPlaydateRequests(
      String userId) async {
    try {
      final response = await _supabase
          .from('playdate_requests')
          .select('''
            *,
            requester:users!requester_id(id, name, avatar_url),
            invitee:users!invitee_id(id, name, avatar_url),
            dog:dogs(id, name, main_photo_url),
            playdate:playdates(id, title, location, scheduled_at)
          ''')
          .or('requester_id.eq.$userId,invitee_id.eq.$userId')
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((item) => PlaydateRequest.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching playdate requests: $e');
      return [];
    }
  }

  // Create a new playdate
  static Future<Playdate?> createPlaydate({
    required String title,
    String? description,
    required String location,
    double? latitude,
    double? longitude,
    required DateTime scheduledAt,
    int durationMinutes = 60,
    int maxDogs = 2,
    required String organizerId,
    required String organizerDogId,
  }) async {
    try {
      // Insert playdate
      final playdateResponse = await _supabase
          .from('playdates')
          .insert({
            'title': title,
            'description': description,
            'location': location,
            'latitude': latitude,
            'longitude': longitude,
            'scheduled_at': scheduledAt.toIso8601String(),
            'duration_minutes': durationMinutes,
            'max_dogs': maxDogs,
            'status': PlaydateStatus.pending.value,
            'organizer_id': organizerId,
          })
          .select()
          .single();

      final playdateId = playdateResponse['id'];

      // Add organizer as participant
      await _supabase.from('playdate_participants').insert({
        'playdate_id': playdateId,
        'user_id': organizerId,
        'dog_id': organizerDogId,
        'is_organizer': true,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Fetch the complete playdate with participants
      return await getPlaydateById(playdateId);
    } catch (e) {
      debugPrint('Error creating playdate: $e');
      return null;
    }
  }

  // Join a playdate
  static Future<bool> joinPlaydate(
      String playdateId, String userId, String dogId) async {
    try {
      // Check if playdate is still available
      final playdate = await getPlaydateById(playdateId);
      if (playdate == null || playdate.isFull || !playdate.canJoin) {
        return false;
      }

      // Add participant
      await _supabase.from('playdate_participants').insert({
        'playdate_id': playdateId,
        'user_id': userId,
        'dog_id': dogId,
        'is_organizer': false,
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Update playdate status to confirmed if it reaches minimum participants
      if (playdate.participants.length + 1 >= 2) {
        await _supabase.from('playdates').update(
            {'status': PlaydateStatus.confirmed.value}).eq('id', playdateId);
      }

      return true;
    } catch (e) {
      debugPrint('Error joining playdate: $e');
      return false;
    }
  }

  // Leave a playdate
  static Future<bool> leavePlaydate(String playdateId, String userId) async {
    try {
      await _supabase
          .from('playdate_participants')
          .delete()
          .eq('playdate_id', playdateId)
          .eq('user_id', userId);

      // Check if organizer left - if so, cancel the playdate
      final playdate = await getPlaydateById(playdateId);
      if (playdate != null && playdate.organizerId == userId) {
        await updatePlaydateStatus(playdateId, PlaydateStatus.cancelled);
      }

      return true;
    } catch (e) {
      debugPrint('Error leaving playdate: $e');
      return false;
    }
  }

  // Update playdate status
  static Future<bool> updatePlaydateStatus(
      String playdateId, PlaydateStatus status) async {
    try {
      await _supabase
          .from('playdates')
          .update({'status': status.value}).eq('id', playdateId);
      return true;
    } catch (e) {
      debugPrint('Error updating playdate status: $e');
      return false;
    }
  }

  // Reschedule playdate
  static Future<bool> reschedulePlaydate(
      String playdateId, DateTime newScheduledAt) async {
    try {
      await _supabase.from('playdates').update({
        'scheduled_at': newScheduledAt.toIso8601String(),
        'status': PlaydateStatus
            .pending.value, // Reset to pending for re-confirmation
      }).eq('id', playdateId);
      return true;
    } catch (e) {
      debugPrint('Error rescheduling playdate: $e');
      return false;
    }
  }

  // Send playdate request/invitation
  static Future<bool> sendPlaydateRequest({
    required String playdateId,
    required String requesterId,
    required String inviteeId,
    required String dogId,
    String? message,
  }) async {
    try {
      await _supabase.from('playdate_requests').insert({
        'playdate_id': playdateId,
        'requester_id': requesterId,
        'invitee_id': inviteeId,
        'dog_id': dogId,
        'message': message,
        'status': PlaydateRequestStatus.pending.value,
      });
      return true;
    } catch (e) {
      debugPrint('Error sending playdate request: $e');
      return false;
    }
  }

  // Respond to playdate request
  static Future<bool> respondToPlaydateRequest(
    String requestId,
    PlaydateRequestStatus response,
  ) async {
    try {
      await _supabase.from('playdate_requests').update({
        'status': response.value,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // If accepted, add to playdate participants
      if (response == PlaydateRequestStatus.accepted) {
        final request = await _getPlaydateRequest(requestId);
        if (request != null) {
          await joinPlaydate(
              request.playdateId, request.inviteeId, request.dogId);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to playdate request: $e');
      return false;
    }
  }

  // Counter-propose playdate with new time/location
  static Future<bool> counterProposePlaydate({
    required String requestId,
    required String playdateId,
    DateTime? newScheduledAt,
    String? newLocation,
    String? message,
  }) async {
    try {
      // Update the playdate with new proposed details
      final updateData = <String, dynamic>{
        'status': PlaydateStatus.pending.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (newScheduledAt != null) {
        updateData['scheduled_at'] = newScheduledAt.toIso8601String();
      }
      if (newLocation != null && newLocation.isNotEmpty) {
        updateData['location'] = newLocation;
      }

      await _supabase.from('playdates').update(updateData).eq('id', playdateId);

      // Update the request status to counter_proposed
      await _supabase.from('playdate_requests').update({
        'status': PlaydateRequestStatus.counterProposed.value,
        'counter_message': message,
        'counter_scheduled_at': newScheduledAt?.toIso8601String(),
        'counter_location': newLocation,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      return true;
    } catch (e) {
      debugPrint('Error counter-proposing playdate: $e');
      return false;
    }
  }

  // Get nearby playdates
  static Future<List<Playdate>> getNearbyPlaydates({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      // For now, get all open playdates - in production would use PostGIS for distance
      final response = await _supabase
          .from('playdates')
          .select('''
            *,
            participants:playdate_participants(
              id,
              user_id,
              dog_id,
              joined_at,
              is_organizer,
              user:users(id, name, avatar_url),
              dog:dogs(id, name, main_photo_url)
            )
          ''')
          .eq('status', PlaydateStatus.pending.value)
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .order('scheduled_at', ascending: true);

      final List<dynamic> data = response;
      return data.map((item) => _parsePlaydateFromResponse(item)).toList();
    } catch (e) {
      debugPrint('Error fetching nearby playdates: $e');
      return [];
    }
  }

  // Get single playdate by ID
  static Future<Playdate?> getPlaydateById(String playdateId) async {
    try {
      final response = await _supabase.from('playdates').select('''
            *,
            participants:playdate_participants(
              id,
              user_id,
              dog_id,
              joined_at,
              is_organizer,
              user:users(id, name, avatar_url),
              dog:dogs(id, name, main_photo_url)
            )
          ''').eq('id', playdateId).single();

      return _parsePlaydateFromResponse(response);
    } catch (e) {
      debugPrint('Error fetching playdate: $e');
      return null;
    }
  }

  // Helper method to get participant playdate IDs
  static Future<String> _getUserParticipantPlaydateIds(String userId) async {
    try {
      final response = await _supabase
          .from('playdate_participants')
          .select('playdate_id')
          .eq('user_id', userId);

      final List<dynamic> data = response;
      if (data.isEmpty) return '';

      final ids = data.map((item) => item['playdate_id']).join(',');
      return ids;
    } catch (e) {
      return '';
    }
  }

  // Helper method to get a single playdate request
  static Future<PlaydateRequest?> _getPlaydateRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('playdate_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      return PlaydateRequest.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Helper method to parse playdate from Supabase response
  static Playdate _parsePlaydateFromResponse(Map<String, dynamic> data) {
    // Parse participants
    final participantsList = <PlaydateParticipant>[];
    if (data['participants'] != null) {
      final participantsData = data['participants'] as List;
      for (final participantData in participantsData) {
        final participant = PlaydateParticipant.fromJson({
          'id': participantData['id'],
          'user_id': participantData['user_id'],
          'user_name': participantData['user']?['name'] ?? '',
          'user_avatar_url': participantData['user']?['avatar_url'],
          'dog_id': participantData['dog_id'],
          'dog_name': participantData['dog']?['name'] ?? '',
          'dog_photo_url': participantData['dog']?['main_photo_url'],
          'joined_at': participantData['joined_at'],
          'is_organizer': participantData['is_organizer'],
        });
        participantsList.add(participant);
      }
    }

    // Find organizer
    final organizer = participantsList.where((p) => p.isOrganizer).firstOrNull;

    return Playdate(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      location: data['location'] ?? '',
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      scheduledAt: DateTime.parse(
          data['scheduled_at'] ?? DateTime.now().toIso8601String()),
      durationMinutes: data['duration_minutes']?.toInt() ?? 60,
      maxDogs: data['max_dogs']?.toInt() ?? 2,
      status: PlaydateStatus.fromString(data['status'] ?? 'pending'),
      createdAt: DateTime.parse(
          data['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          data['updated_at'] ?? DateTime.now().toIso8601String()),
      participants: participantsList,
      organizerId: organizer?.userId ?? data['organizer_id'] ?? '',
      organizerName: organizer?.userName ?? '',
      organizerAvatarUrl: organizer?.userAvatarUrl,
    );
  }

  // Get user's dogs (using the enhanced dog model for many-to-many support)
  static Future<List<EnhancedDog>> getUserDogs(String userId) async {
    try {
      // Get dogs where user is owner (many-to-many)
      final response = await _supabase.from('dog_owners').select('''
            *,
            dog:dogs(*)
          ''').eq('user_id', userId);

      final List<dynamic> data = response;
      final dogs = <EnhancedDog>[];

      for (final ownershipData in data) {
        final dogData = ownershipData['dog'];
        if (dogData != null) {
          final dog = EnhancedDog.fromDatabase(dogData);
          dogs.add(dog);
        }
      }

      return dogs;
    } catch (e) {
      debugPrint('Error fetching user dogs: $e');
      return [];
    }
  }
}
