import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart'; // Using the shared provider file
import 'package:barkdate/models/message.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/app_button.dart';
import 'package:barkdate/design_system/app_styles.dart';

import 'package:intl/intl.dart' as intl;

class ChatScreen extends ConsumerStatefulWidget {
  final String matchId;
  final String recipientId;
  final String recipientName;
  final String? recipientAvatarUrl;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatarUrl,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isInputRtl = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_checkInputDirection);
  }

  void _checkInputDirection() {
    final text = _messageController.text;
    final isRtl = intl.Bidi.detectRtlDirectionality(text);
    if (isRtl != _isInputRtl) {
      setState(() {
        _isInputRtl = isRtl;
      });
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_checkInputDirection);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use stream provider for real-time updates
    final messagesAsync = ref.watch(messagesStreamProvider(widget.matchId));
    final currentUser = SupabaseConfig.auth.currentUser;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.recipientAvatarUrl != null
                    ? NetworkImage(widget.recipientAvatarUrl!)
                    : null,
                child: widget.recipientAvatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.recipientName,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messagesData) {
                  // Convert Map to Message objects if needed, or use Map directly
                  // The repository returns List<Map<String, dynamic>>
                  // Let's map them to Message objects for easier handling
                  final messages = messagesData.map((data) {
                    return Message(
                      id: data['id'] as String,
                      senderId: data['sender_id'] as String,
                      receiverId: data['receiver_id'] as String,
                      text: data['content'] as String,
                      timestamp: DateTime.parse(data['created_at'] as String),
                      isRead: data['is_read'] ?? false,
                    );
                  }).toList();

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Say hello! 👋'),
                    );
                  }

                  // Auto-scroll to bottom after messages load
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    reverse:
                        false, // Messages are usually ordered by created_at ascending
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUser?.id;
                      return _buildMessageBubble(context, message, isMe);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
            _buildMessageInput(currentUser?.id),
          ],
        ),
      ),
    );
  }

  /// Scroll to the bottom of the chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe) {
    final isRtl = intl.Bidi.detectRtlDirectionality(message.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.recipientAvatarUrl != null
                  ? NetworkImage(widget.recipientAvatarUrl!)
                  : null,
              child: widget.recipientAvatarUrl == null
                  ? const Icon(Icons.person, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  color: isMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String? currentUserId) {
    return Container(
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
          Expanded(
            child: TextField(
              controller: _messageController,
              textDirection:
                  _isInputRtl ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            color: Theme.of(context).colorScheme.primary,
            onPressed: _isSending || currentUserId == null
                ? null
                : () => _sendMessage(currentUserId),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String currentUserId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await ref.read(messageRepositoryProvider).sendMessage(
            matchId: widget.matchId,
            senderId: currentUserId,
            receiverId: widget.recipientId,
            content: text,
          );
      _messageController.clear();
      // Scroll to bottom after sending
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }
}
