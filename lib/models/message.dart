class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final MessageType type;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? timestamp,
    bool? isRead,
    MessageType? type,
  }) =>
      Message(
        id: id ?? this.id,
        senderId: senderId ?? this.senderId,
        receiverId: receiverId ?? this.receiverId,
        text: text ?? this.text,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        type: type ?? this.type,
      );
}

enum MessageType { text, image, quickReply }

class ChatPreview {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherDogName;
  final String otherDogPhoto;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const ChatPreview({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherDogName,
    required this.otherDogPhoto,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });
}
