abstract class MessageRepository {
  Future<List<Map<String, dynamic>>> getConversations(String userId);
  Future<List<Map<String, dynamic>>> getMessages(String matchId);
  Future<Map<String, dynamic>> sendMessage({
    required String matchId,
    required String senderId,
    String? receiverId,
    required String content,
    String messageType = 'text',
  });
  Future<void> markMessagesAsRead(String matchId, String userId);
  Future<List<Map<String, dynamic>>> getMutualMatches(String userId);
}
