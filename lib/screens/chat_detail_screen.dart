import 'package:flutter/material.dart';
import 'package:barkdate/models/message.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'dart:async';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/design_system/app_styles.dart';

class ChatDetailScreen extends StatefulWidget {
  final String recipientName;
  final String? dogName;
  final String? matchId; // For real messaging
  final String? recipientId; // For real messaging

  const ChatDetailScreen({
    super.key, 
    required this.recipientName,
    this.dogName,
    this.matchId,
    this.recipientId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _messageSubscription;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  void _getCurrentUser() {
    final user = SupabaseAuth.currentUser;
    _currentUserId = user?.id;
  }

  void _subscribeToMessages() {
    if (widget.matchId == null) return;

    // Real-time message subscription! ⚡
    _messageSubscription = SupabaseConfig.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', widget.matchId!)
        .listen((data) {
          final newMessages = data.map((item) {
            return Message(
              id: item['id'] as String,
              senderId: item['sender_id'] as String,
              receiverId: item['receiver_id'] as String,
              text: item['content'] as String,
              timestamp: DateTime.parse(item['created_at'] as String),
            );
          }).toList();

          setState(() {
            _messages = newMessages;
          });

          _scrollToBottom();
        });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadMessages() async {
    if (widget.matchId == null) {
      // If no real match ID, show sample conversation
      setState(() {
        _messages = [
          Message(
            id: 'sample_1',
            senderId: widget.recipientId ?? 'other_user',
            receiverId: _currentUserId ?? 'current_user',
            text: 'Hey! How\'s it going? Ready for our doggy playdate tomorrow?',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          Message(
            id: 'sample_2',
            senderId: _currentUserId ?? 'current_user',
            receiverId: widget.recipientId ?? 'other_user',
            text: 'Hi ${widget.recipientName}! Yes, we\'re super excited! What time were you thinking?',
            timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
          ),
          Message(
            id: 'sample_3',
            senderId: widget.recipientId ?? 'other_user',
            receiverId: _currentUserId ?? 'current_user',
            text: 'How about 10 AM at the park? It\'s supposed to be sunny!',
            timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
          ),
        ];
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }

    try {
      // Load real messages from database! 💬
      final messageData = await BarkDateMessageService.getMessages(widget.matchId!);
      
      final messages = messageData.map((data) {
        return Message(
          id: data['id'] as String,
          senderId: data['sender_id'] as String,
          receiverId: data['receiver_id'] as String,
          text: data['content'] as String,
          timestamp: DateTime.parse(data['created_at'] as String),
        );
      }).toList();

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      // Mark messages as read
      if (_currentUserId != null) {
        await BarkDateMessageService.markMessagesAsRead(widget.matchId!, _currentUserId!);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=200'),
              onBackgroundImageError: (exception, stackTrace) {},
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.recipientName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId == (_currentUserId ?? 'current_user');
                      return _buildMessageBubble(context, message, isMe);
                    },
                  ),
          ),
          // Quick replies
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickReplyChip(context, 'On my way! 🚗'),
                  const SizedBox(width: 8),
                  _buildQuickReplyChip(context, 'Running late 🕐'),
                  const SizedBox(width: 8),
                  _buildQuickReplyChip(context, 'See you soon 🐾'),
                ],
              ),
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.camera_alt_outlined,
                  onPressed: () {},
                  hasBorder: true,
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  icon: Icons.photo_outlined,
                  onPressed: () {},
                  hasBorder: true,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.recipientName}...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppStyles.borderRadiusSM,
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : AppIconButton(
                        icon: Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: const NetworkImage('https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=200'),
              onBackgroundImageError: (exception, stackTrace) {},
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppStyles.radiusLG).copyWith(
                  bottomLeft: Radius.circular(isMe ? AppStyles.radiusLG : AppStyles.radiusXS),
                  bottomRight: Radius.circular(isMe ? AppStyles.radiusXS : AppStyles.radiusLG),
                ),
              ),
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isMe 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.person,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReplyChip(BuildContext context, String text) {
    return GestureDetector(
      onTap: () => _sendQuickReply(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    
    final messageText = _messageController.text.trim();
    _messageController.clear();

    if (widget.matchId == null || widget.recipientId == null || _currentUserId == null) {
      // For demo mode, just add to local list
      setState(() {
        _messages.add(Message(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _currentUserId ?? 'current_user',
          receiverId: widget.recipientId ?? 'other_user',
          text: messageText,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() => _isSending = true);

    try {
      // Send real message to database! 🚀
      await BarkDateMessageService.sendMessage(
        matchId: widget.matchId!,
        senderId: _currentUserId!,
        receiverId: widget.recipientId!,
        content: messageText,
      );

      // Message will appear via real-time subscription
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      
      // Show error and restore message
      if (mounted) {
        _messageController.text = messageText;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _sendQuickReply(String text) {
    _messageController.text = text;
    _sendMessage();
  }
}