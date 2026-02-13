import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time chat service using Supabase Realtime Broadcast
/// Based on Supabase UI patterns: https://supabase.com/ui/docs/nextjs/realtime-chat
class RealtimeChatService {
  static final _client = SupabaseConfig.client;
  
  RealtimeChannel? _channel;
  final StreamController<ChatMessage> _messageController = StreamController.broadcast();
  
  /// Stream of incoming messages
  Stream<ChatMessage> get messageStream => _messageController.stream;
  
  /// Current room name
  String? _currentRoom;
  
  /// Join a chat room and start receiving messages
  Future<void> joinRoom({
    required String roomName,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    // Leave existing room first
    await leaveRoom();
    
    _currentRoom = roomName;
    
    _channel = _client.channel('chat:$roomName');
    
    _channel!
      .onBroadcast(
        event: 'message',
        callback: (payload) {
          try {
            final message = ChatMessage.fromJson(payload);
            _messageController.add(message);
            debugPrint('📩 Received message: ${message.content}');
          } catch (e) {
            debugPrint('❌ Error parsing message: $e');
          }
        },
      )
      .subscribe((status, error) {
        debugPrint('🔌 Chat channel status: $status');
        if (error != null) {
          debugPrint('❌ Chat channel error: $error');
        }
      });
    
    debugPrint('✅ Joined chat room: $roomName');
  }
  
  /// Send a message to the current room
  Future<bool> sendMessage({
    required String content,
    required String userId,
    required String userName,
    String? userAvatar,
    bool storeInDatabase = true,
  }) async {
    if (_channel == null || _currentRoom == null) {
      debugPrint('❌ Not connected to a room');
      return false;
    }
    
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      createdAt: DateTime.now(),
      roomName: _currentRoom!,
    );
    
    try {
      // Broadcast to all clients in real-time
      await _channel!.sendBroadcastMessage(
        event: 'message',
        payload: message.toJson(),
      );
      
      debugPrint('📤 Sent message: $content');
      
      // Optionally store in database for persistence
      if (storeInDatabase) {
        await _storeMessage(message);
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }
  
  /// Store message in database for history
  Future<void> _storeMessage(ChatMessage message) async {
    try {
      // Parse room name to get match_id (format: "chat:{matchId}")
      final matchId = _currentRoom?.replaceFirst('chat:', '');
      
      await _client.from('messages').insert({
        'match_id': matchId,
        'sender_id': message.userId,
        'content': message.content,
        'message_type': 'text',
        'created_at': message.createdAt.toIso8601String(),
      });
      
      debugPrint('💾 Message stored in database');
    } catch (e) {
      debugPrint('⚠️ Failed to store message: $e');
      // Don't throw - message was still sent in real-time
    }
  }
  
  /// Leave the current room
  Future<void> leaveRoom() async {
    if (_channel != null) {
      await _client.removeChannel(_channel!);
      _channel = null;
      debugPrint('👋 Left chat room: $_currentRoom');
      _currentRoom = null;
    }
  }
  
  /// Load message history from database
  Future<List<ChatMessage>> loadHistory({
    required String roomName,
    int limit = 50,
  }) async {
    try {
      final matchId = roomName.replaceFirst('chat:', '');
      
      final data = await _client
          .from('messages')
          .select('*, sender:users!sender_id(id, name, avatar_url)')
          .eq('match_id', matchId)
          .order('created_at', ascending: true)
          .limit(limit);
      
      return (data as List).map((row) {
        final sender = row['sender'] as Map<String, dynamic>?;
        return ChatMessage(
          id: row['id'],
          content: row['content'] ?? '',
          userId: row['sender_id'],
          userName: sender?['name'] ?? 'Unknown',
          userAvatar: sender?['avatar_url'],
          createdAt: DateTime.parse(row['created_at']),
          roomName: roomName,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading history: $e');
      return [];
    }
  }
  
  /// Dispose resources
  void dispose() {
    leaveRoom();
    _messageController.close();
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String content;
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime createdAt;
  final String roomName;
  
  ChatMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.createdAt,
    required this.roomName,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Unknown',
      userAvatar: json['userAvatar'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      roomName: json['roomName'] ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'createdAt': createdAt.toIso8601String(),
      'roomName': roomName,
    };
  }
}
