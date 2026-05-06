import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:barkdate/features/notifications/presentation/widgets/notifications_app_bar.dart';
import 'package:barkdate/core/router/app_routes.dart';

import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/widgets/receive_walk_sheet.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/services/dog_friendship_service.dart';
import 'package:barkdate/features/messages/presentation/screens/chat_screen.dart';

/// Provider for notifications
final notificationsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = SupabaseConfig.auth.currentUser;
  if (user == null) return Stream.value([]);

  return NotificationService.streamUserNotifications(user.id);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const NotificationsAppBar(),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: AppTypography.bodyMedium().copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see barks, playdate requests,\nand more here',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall().copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(context, notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Error loading notifications: $error'),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      BuildContext context, Map<String, dynamic> notification) {
    final type = notification['type'] as String? ?? 'general';
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['is_read'] as bool? ?? false;
    final createdAt =
        DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now();
    final notificationId = notification['id'] as String?;
    final relatedId = notification['related_id'] as String?;
    final metadata = notification['metadata'] as Map<String, dynamic>?;

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'bark':
        icon = Icons.pets;
        iconColor = const Color(0xFFE89E5F); // Orange to match Add to Pack
        break;
      case 'playdate_request':
        icon = Icons.calendar_today;
        iconColor = const Color(0xFFED924D);
        break;
      case 'playdate_confirmed':
        icon = Icons.check_circle;
        iconColor = const Color(0xFF4CAF50);
        break;
      case 'message':
        icon = Icons.chat_bubble_outline;
        iconColor = const Color(0xFFE885DC);
        break;
      case 'event':
        icon = Icons.event;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return ListTile(
      onTap: () async {
        // 1. Mark as read
        if (notificationId != null && !isRead) {
          await NotificationService.markAsRead(notificationId);
        }

        // 2. Route based on type
        if (!context.mounted) return;

        switch (type) {
          case 'playdate_request':
            if (metadata != null &&
                metadata['organizer_dog_name'] != null &&
                metadata['location'] != null) {
              showReceiveWalkSheetFromPayload(context, metadata);
            } else {
              const PlaydatesRoute().push(context);
            }
            break;
          case 'playdate_confirmed':
          case 'playdate':
            final pId = metadata?['playdate_id'] as String?;
            if (pId != null) {
              try {
                final conv =
                    await ConversationService.getPlaydateConversation(pId);
                if (conv != null && context.mounted) {
                  final convId = conv['id'] as String;
                  if (!ChatNavigationGuard.canPush(convId)) break;
                  final respName =
                      metadata?['responder_name'] as String? ?? 'Walk buddy';
                  ChatRoute(
                    matchId: convId,
                    recipientId: '',
                    recipientName: respName,
                    recipientAvatarUrl: '',
                  ).push(context);
                  break;
                }
              } catch (_) {}
            }
            if (!context.mounted) return;
            const PlaydatesRoute().push(context);
            break;
          case 'message':
            if (metadata != null && metadata['conversation_id'] != null) {
              final convId = metadata['conversation_id'] as String;
              if (ChatNavigationGuard.canPush(convId)) {
                ChatRoute(
                  matchId: convId,
                  recipientId: '',
                  recipientName: 'Unknown',
                  recipientAvatarUrl: '',
                ).push(context);
              }
            } else {
              const MessagesRoute().push(context);
            }
            break;
          case 'bark':
            // Navigate to dog profile if we have the dog ID
            if (relatedId != null) {
              DogDetailsByIdRoute(id: relatedId).push(context);
            }
            break;
          case 'event':
            // Navigate to events
            const EventsRoute().push(context);
            break;
          default:
            // Just close and stay on notifications
            break;
        }
      },
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium().copyWith(
          fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style:
                  AppTypography.bodySmall().copyWith(color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            timeago.format(createdAt),
            style: AppTypography.caption().copyWith(color: Colors.grey[500]),
          ),
          // Sprint 8: inline Accept / Ignore for bark (pack request)
          if (type == 'bark' && !isRead) ...[
            const SizedBox(height: 8),
            _BarkActionButtons(
              friendshipId: metadata?['friendship_id'] as String?,
              notificationId: notificationId,
              senderDogName: metadata?['sender_dog_name'] as String? ?? '',
            ),
          ],
        ],
      ),
      trailing: !isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE89E5F),
                shape: BoxShape.circle,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    );
  }
}

/// Sprint 8: Inline Accept / Ignore buttons for bark notifications.
/// Stateful so it can show a loading spinner and swap to a result message
/// after the user taps.
class _BarkActionButtons extends ConsumerStatefulWidget {
  final String? friendshipId;
  final String? notificationId;
  final String senderDogName;

  const _BarkActionButtons({
    required this.friendshipId,
    required this.notificationId,
    required this.senderDogName,
  });

  @override
  ConsumerState<_BarkActionButtons> createState() => _BarkActionButtonsState();
}

class _BarkActionButtonsState extends ConsumerState<_BarkActionButtons> {
  bool _loading = false;
  String? _result; // 'accepted' | 'declined' | null

  Future<void> _accept() async {
    if (widget.friendshipId == null) return;
    setState(() => _loading = true);
    final success =
        await DogFriendshipService.acceptBark(widget.friendshipId!);
    if (success && widget.notificationId != null) {
      await NotificationService.markAsRead(widget.notificationId!);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _result = success ? 'accepted' : null;
      });
      if (success) {
        ref.invalidate(notificationsProvider);
      }
    }
  }

  Future<void> _decline() async {
    if (widget.friendshipId == null) return;
    setState(() => _loading = true);
    final success =
        await DogFriendshipService.removeFriendship(widget.friendshipId!);
    if (success && widget.notificationId != null) {
      await NotificationService.markAsRead(widget.notificationId!);
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _result = success ? 'declined' : null;
      });
      if (success) {
        ref.invalidate(notificationsProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 32,
        child: Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (_result == 'accepted') {
      return Text(
        '${widget.senderDogName} joined your pack! 🎉',
        style: AppTypography.bodySmall().copyWith(
          color: const Color(0xFF4CAF50),
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_result == 'declined') {
      return Text(
        'Request declined',
        style: AppTypography.bodySmall().copyWith(color: Colors.grey[500]),
      );
    }

    // Show Accept / Ignore pair
    return Row(
      children: [
        SizedBox(
          height: 32,
          child: ElevatedButton(
            onPressed: _accept,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFCF5EE),
              foregroundColor: Colors.orange[800],
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: _decline,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[600],
              side: BorderSide(color: Colors.grey[300]!),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ignore',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
