import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/notification_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing dog friendships (barks)
/// A "bark" is a friend request between dogs
class DogFriendshipService {
  static final _supabase = SupabaseConfig.client;

  /// Status constants
  static const statusPending = 'pending';
  static const statusAccepted = 'accepted';
  static const statusDeclined = 'declined';

  /// Send a bark (friend request) from one dog to another
  static Future<bool> sendBark({
    required String fromDogId,
    required String toDogId,
    String? message,
  }) async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Prevent self-friend requests
      if (fromDogId == toDogId) {
        debugPrint('Cannot send bark to yourself');
        return false;
      }

      // Check if friendship already exists
      final existing = await _supabase
          .from('dog_friendships')
          .select()
          .or('and(dog_id.eq.$fromDogId,friend_dog_id.eq.$toDogId),and(dog_id.eq.$toDogId,friend_dog_id.eq.$fromDogId)')
          .maybeSingle();

      if (existing != null) {
        debugPrint('Friendship already exists with status: ${existing['status']}');
        return false; // Already friends or pending
      }

      // Create new friendship request
      await _supabase.from('dog_friendships').insert({
        'dog_id': fromDogId,
        'friend_dog_id': toDogId,
        'status': statusPending,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('🐕 Bark sent from $fromDogId to $toDogId');
      
      // TODO: Send notification to the other dog's owner
      // Would need to get the owner's user_id from the dog profile
      
      return true;
    } catch (e) {
      debugPrint('Error sending bark: $e');
      return false;
    }
  }

  /// Accept a bark (friend request)
  static Future<bool> acceptBark(String friendshipId) async {
    try {
      await _supabase
          .from('dog_friendships')
          .update({
            'status': statusAccepted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId);

      debugPrint('✅ Bark accepted: $friendshipId');
      return true;
    } catch (e) {
      debugPrint('Error accepting bark: $e');
      return false;
    }
  }

  /// Decline a bark (friend request)
  static Future<bool> declineBark(String friendshipId) async {
    try {
      await _supabase
          .from('dog_friendships')
          .update({
            'status': statusDeclined,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId);

      debugPrint('❌ Bark declined: $friendshipId');
      return true;
    } catch (e) {
      debugPrint('Error declining bark: $e');
      return false;
    }
  }

  /// Remove a friendship (unfriend/un-bark)
  static Future<bool> removeFriendship(String friendshipId) async {
    try {
      await _supabase
          .from('dog_friendships')
          .delete()
          .eq('id', friendshipId);

      debugPrint('🗑️ Friendship removed: $friendshipId');
      return true;
    } catch (e) {
      debugPrint('Error removing friendship: $e');
      return false;
    }
  }

  /// Get friendship status between two dogs
  /// Returns: null (no relationship), 'pending', 'accepted', 'declined'
  static Future<Map<String, dynamic>?> getFriendshipStatus({
    required String dogId1,
    required String dogId2,
  }) async {
    try {
      final result = await _supabase
          .from('dog_friendships')
          .select()
          .or('and(dog_id.eq.$dogId1,friend_dog_id.eq.$dogId2),and(dog_id.eq.$dogId2,friend_dog_id.eq.$dogId1)')
          .maybeSingle();

      return result;
    } catch (e) {
      debugPrint('Error getting friendship status: $e');
      return null;
    }
  }

  /// Get pending bark requests for a dog (received requests)
  /// Returns the requesting dog's info including their owner's name and avatar
  static Future<List<Map<String, dynamic>>> getPendingBarksReceived(String dogId) async {
    try {
      final result = await _supabase
          .from('dog_friendships')
          .select('*, requester:dogs!dog_friendships_dog_id_fkey(id, name, breed, main_photo_url, user_id, user:users!dogs_user_id_fkey(id, name, avatar_url))')
          .eq('friend_dog_id', dogId)
          .eq('status', statusPending);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting pending barks: $e');
      return [];
    }
  }

  /// Stream pending bark requests for a dog (real-time)
  static Stream<List<Map<String, dynamic>>> streamPendingBarksReceived(String dogId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // Initial fetch
    getPendingBarksReceived(dogId).then((barks) {
      if (!controller.isClosed) controller.add(barks);
    });

    final channel = _supabase
        .channel('public:dog_friendships_pending_$dogId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'dog_friendships',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            
            // Refetch if this change involves our dog as the friend (receiver)
            bool isRelevant = false;
            
            if (newRecord.isNotEmpty && newRecord['friend_dog_id'] == dogId) isRelevant = true;
            if (oldRecord.isNotEmpty && oldRecord['friend_dog_id'] == dogId) isRelevant = true;
            
            if (isRelevant) {
               getPendingBarksReceived(dogId).then((barks) {
                 if (!controller.isClosed) controller.add(barks);
               });
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Get pending bark requests sent by a dog
  static Future<List<Map<String, dynamic>>> getPendingBarksSent(String dogId) async {
    try {
      final result = await _supabase
          .from('dog_friendships')
          .select('*, friend_dog:dogs!dog_friendships_friend_dog_id_fkey(id, name, breed, main_photo_url, user_id)')
          .eq('dog_id', dogId)
          .eq('status', statusPending);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting sent barks: $e');
      return [];
    }
  }

  /// Get all friends (accepted barks) for a dog
  static Future<List<Map<String, dynamic>>> getFriends(String dogId) async {
    try {
      // Get friendships where this dog is either the sender or receiver
      final result = await _supabase
          .from('dog_friendships')
          .select('*, dog:dogs!dog_friendships_dog_id_fkey(id, name, breed, main_photo_url), friend_dog:dogs!dog_friendships_friend_dog_id_fkey(id, name, breed, main_photo_url)')
          .eq('status', statusAccepted)
          .or('dog_id.eq.$dogId,friend_dog_id.eq.$dogId');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error getting friends: $e');
      return [];
    }
  }

  /// Check if two dogs are friends
  static Future<bool> areFriends(String dogId1, String dogId2) async {
    final status = await getFriendshipStatus(dogId1: dogId1, dogId2: dogId2);
    return status?['status'] == statusAccepted;
  }

  /// Check if a bark is pending from one dog to another
  static Future<bool> hasPendingBark(String fromDogId, String toDogId) async {
    final status = await getFriendshipStatus(dogId1: fromDogId, dogId2: toDogId);
    return status?['status'] == statusPending;
  }
}
