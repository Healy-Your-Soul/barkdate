import 'package:barkdate/features/messages/domain/repositories/message_repository.dart';
import 'package:barkdate/supabase/barkdate_services.dart';

class MessageRepositoryImpl implements MessageRepository {
  @override
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    return await BarkDateMessageService.getConversations(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String matchId) async {
    return await BarkDateMessageService.getMessages(matchId);
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String matchId,
    required String senderId,
    required String receiverId,
    required String content,
    String messageType = 'text',
  }) async {
    return await BarkDateMessageService.sendMessage(
      matchId: matchId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      messageType: messageType,
    );
  }

  @override
  Future<void> markMessagesAsRead(String matchId, String userId) async {
    await BarkDateMessageService.markMessagesAsRead(matchId, userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getMutualMatches(String userId) async {
    return await BarkDateMatchService.getMutualMatches(userId);
  }
}
