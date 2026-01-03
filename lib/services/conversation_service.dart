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

    debugPrint('💬 Getting or creating conversation between $orderedUser1 and $orderedUser2');

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
  static Future<List<Map<String, dynamic>>> getUserConversations(String userId) async {
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
}
