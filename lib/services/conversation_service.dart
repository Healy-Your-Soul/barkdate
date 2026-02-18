import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Service for managing conversations between users
class ConversationService {
  static final _client = SupabaseConfig.client;

  /// Get or create a conversation between two users
  /// Returns the conversation ID
  static Future<String> getOrCreateConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    // Ensure consistent ordering (smaller UUID first) for unique constraint
    final ids = [user1Id, user2Id]..sort();
    final orderedUser1 = ids[0];
    final orderedUser2 = ids[1];

    debugPrint(
        '💬 Getting or creating conversation between $orderedUser1 and $orderedUser2');

    try {
      // Check if conversation already exists
      final existing = await _client
          .from('conversations')
          .select('id')
          .eq('user1_id', orderedUser1)
          .eq('user2_id', orderedUser2)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ Found existing conversation: ${existing['id']}');
        return existing['id'] as String;
      }

      // Create new conversation
      final created = await _client
          .from('conversations')
          .insert({
            'user1_id': orderedUser1,
            'user2_id': orderedUser2,
          })
          .select('id')
          .single();

      debugPrint('✅ Created new conversation: ${created['id']}');
      return created['id'] as String;
    } catch (e) {
      debugPrint('❌ Error in getOrCreateConversation: $e');
      rethrow;
    }
  }

  /// Get all conversations for a user with latest message preview
  static Future<List<Map<String, dynamic>>> getUserConversations(
      String userId) async {
    try {
      final data = await _client
          .from('conversations')
          .select('''
            id,
            created_at,
            updated_at,
            last_message_at,
            user1:user1_id(id, name, avatar_url),
            user2:user2_id(id, name, avatar_url)
          ''')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_message_at', ascending: false);

      // Map to include the "other user" for easier display
      return (data as List).map((conv) {
        final user1 = conv['user1'] as Map<String, dynamic>?;
        final user2 = conv['user2'] as Map<String, dynamic>?;

        // Determine who the "other" user is
        final isUser1 = user1?['id'] == userId;
        final otherUser = isUser1 ? user2 : user1;

        return {
          'id': conv['id'],
          'created_at': conv['created_at'],
          'updated_at': conv['updated_at'],
          'last_message_at': conv['last_message_at'],
          'other_user_id': otherUser?['id'],
          'other_user_name': otherUser?['name'] ?? 'Unknown',
          'other_user_avatar': otherUser?['avatar_url'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching conversations: $e');
      return [];
    }
  }

  /// Update last message timestamp for a conversation
  static Future<void> updateLastMessageTime(String conversationId) async {
    try {
      await _client.from('conversations').update({
        'last_message_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('⚠️ Failed to update conversation timestamp: $e');
    }
  }

  // ============ GROUP CHAT / PLAYDATE CONVERSATION METHODS ============

  /// Create or get conversation for a playdate
  /// Works for any playdate (single or multi-participant)
  static Future<String?> getOrCreatePlaydateConversation({
    required String playdateId,
    required List<String> participantUserIds,
    required String groupName,
  }) async {
    if (participantUserIds.isEmpty) {
      debugPrint('❌ No participants provided for playdate conversation');
      return null;
    }

    debugPrint(
        '🎾 Creating playdate conversation for $playdateId with ${participantUserIds.length} participants');

    try {
      // Check if conversation already exists for this playdate
      final existing = await _client
          .from('conversations')
          .select('id')
          .eq('playdate_id', playdateId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('✅ Found existing playdate conversation: ${existing['id']}');
        return existing['id'] as String;
      }

      // Determine if this is a group (2+ participants) or 1:1
      final isGroup = participantUserIds.length > 2;

      // Create new conversation
      final conversationData = <String, dynamic>{
        'is_group': isGroup,
        'playdate_id': playdateId,
        'group_name': groupName,
        'last_message_at': DateTime.now().toIso8601String(),
      };

      // For 2-person playdates, also set user1_id and user2_id for compatibility
      if (participantUserIds.length == 2) {
        final ids = [...participantUserIds]..sort();
        conversationData['user1_id'] = ids[0];
        conversationData['user2_id'] = ids[1];
      }

      final created = await _client
          .from('conversations')
          .insert(conversationData)
          .select('id')
          .single();

      final conversationId = created['id'] as String;
      debugPrint('✅ Created playdate conversation: $conversationId');

      // Add all participants
      for (int i = 0; i < participantUserIds.length; i++) {
        final userId = participantUserIds[i];
        await _client.from('conversation_participants').insert({
          'conversation_id': conversationId,
          'user_id': userId,
          'role': i == 0
              ? 'admin'
              : 'member', // First participant is admin (organizer)
        });
      }
      debugPrint('✅ Added ${participantUserIds.length} participants');

      // Post welcome system message
      await postSystemMessage(
        conversationId,
        '🎾 Playdate chat created! Coordinate details here.',
      );

      return conversationId;
    } catch (e) {
      debugPrint('❌ Error creating playdate conversation: $e');
      return null;
    }
  }

  /// Get conversation for a specific playdate
  static Future<Map<String, dynamic>?> getPlaydateConversation(
      String playdateId) async {
    try {
      final data = await _client.from('conversations').select('''
            id,
            is_group,
            group_name,
            playdate_id,
            last_message_at,
            created_at
          ''').eq('playdate_id', playdateId).maybeSingle();

      return data;
    } catch (e) {
      debugPrint('❌ Error fetching playdate conversation: $e');
      return null;
    }
  }

  /// Get all participants in a group conversation
  static Future<List<Map<String, dynamic>>> getGroupParticipants(
      String conversationId) async {
    try {
      final data = await _client.from('conversation_participants').select('''
            id,
            user_id,
            role,
            joined_at,
            user:user_id(id, name, avatar_url)
          ''').eq('conversation_id', conversationId);

      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error fetching group participants: $e');
      return [];
    }
  }

  /// Add a participant to a group conversation
  static Future<bool> addParticipant(String conversationId, String userId,
      {String role = 'member'}) async {
    try {
      await _client.from('conversation_participants').insert({
        'conversation_id': conversationId,
        'user_id': userId,
        'role': role,
      });
      debugPrint('✅ Added participant $userId to conversation');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding participant: $e');
      return false;
    }
  }

  /// Post a system message (for playdate updates)
  static Future<void> postSystemMessage(
      String conversationId, String text) async {
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'content': text,
        'is_system_message': true,
        'sender_id': null, // System messages have no sender
      });
      await updateLastMessageTime(conversationId);
      debugPrint('📢 Posted system message: $text');
    } catch (e) {
      debugPrint('❌ Error posting system message: $e');
    }
  }

  /// Get all conversations for a user (including group chats)
  static Future<List<Map<String, dynamic>>> getAllUserConversations(
      String userId) async {
    try {
      // Get direct conversations (1:1)
      final directConversations = await getUserConversations(userId);

      // Get group conversations via participants table
      final groupData =
          await _client.from('conversation_participants').select('''
            conversation:conversation_id(
              id,
              is_group,
              group_name,
              playdate_id,
              last_message_at,
              created_at
            )
          ''').eq('user_id', userId);

      final groupConversations = (groupData as List)
          .where((item) =>
              item['conversation'] != null &&
              item['conversation']['is_group'] == true)
          .map<Map<String, dynamic>>((item) {
        final conv = item['conversation'] as Map<String, dynamic>;
        return {
          'id': conv['id'],
          'is_group': true,
          'group_name': conv['group_name'] ?? 'Playdate Chat',
          'playdate_id': conv['playdate_id'],
          'last_message_at': conv['last_message_at'],
          'created_at': conv['created_at'],
        };
      }).toList();

      // Combine and sort by last_message_at
      final allConversations = [...directConversations, ...groupConversations];
      allConversations.sort((a, b) {
        final aTime = a['last_message_at'] ?? a['created_at'] ?? '';
        final bTime = b['last_message_at'] ?? b['created_at'] ?? '';
        return bTime.compareTo(aTime);
      });

      return allConversations;
    } catch (e) {
      debugPrint('❌ Error fetching all conversations: $e');
      return [];
    }
  }
}
