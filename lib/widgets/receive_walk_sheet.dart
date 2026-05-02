import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/notification_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:barkdate/core/router/app_router.dart';
import 'package:barkdate/features/feed/presentation/providers/friend_activity_provider.dart';
import 'package:barkdate/features/playdates/presentation/providers/playdate_provider.dart';

class ReceiveWalkSheet extends ConsumerStatefulWidget {
  final String requestId;
  final String organizerName;
  final String dogName;
  final String? dogPhotoUrl;
  final String location;
  final DateTime scheduledAt;

  const ReceiveWalkSheet({
    super.key,
    required this.requestId,
    required this.organizerName,
    required this.dogName,
    this.dogPhotoUrl,
    required this.location,
    required this.scheduledAt,
  });

  @override
  ConsumerState<ReceiveWalkSheet> createState() => _ReceiveWalkSheetState();
}

class _ReceiveWalkSheetState extends ConsumerState<ReceiveWalkSheet> {
  bool _isLoading = false;

  Future<Map<String, dynamic>?> _fetchRequestContext() async {
    try {
      final request =
          await SupabaseConfig.client.from('playdate_requests').select('''
            id,
            playdate_id,
            playdate:playdates(id, title, location, scheduled_at)
          ''').eq('id', widget.requestId).maybeSingle();

      if (request == null) return null;
      return Map<String, dynamic>.from(request);
    } catch (e) {
      debugPrint('Could not fetch request context: $e');
      return null;
    }
  }

  Future<Map<String, String>?> _resolveAcceptedChatTarget() async {
    try {
      final request =
          await SupabaseConfig.client.from('playdate_requests').select('''
            playdate_id,
            requester_id,
            requester:users!playdate_requests_requester_id_fkey(name, avatar_url)
          ''').eq('id', widget.requestId).maybeSingle();

      if (request == null) return null;

      final requesterId = request['requester_id'] as String?;
      final playdateId = request['playdate_id'] as String?;
      final requester = request['requester'] as Map<String, dynamic>?;

      if (requesterId == null || playdateId == null) return null;

      final playdateConversation =
          await ConversationService.getPlaydateConversation(playdateId);

      String conversationId;
      if (playdateConversation != null && playdateConversation['id'] != null) {
        conversationId = playdateConversation['id'] as String;
      } else {
        final currentUser = SupabaseConfig.auth.currentUser;
        if (currentUser == null) return null;
        conversationId = await ConversationService.getOrCreateConversation(
          user1Id: currentUser.id,
          user2Id: requesterId,
        );
      }

      return {
        'conversationId': conversationId,
        'recipientId': requesterId,
        'recipientName':
            (requester?['name'] as String?) ?? widget.organizerName,
        'recipientAvatarUrl': (requester?['avatar_url'] as String?) ?? '',
      };
    } catch (e) {
      debugPrint('Could not resolve accepted chat target: $e');
      return null;
    }
  }

  Future<void> _postWalkSystemMessage(
      String playdateId, String userId, String status) async {
    try {
      final conversation =
          await ConversationService.getPlaydateConversation(playdateId);
      if (conversation == null) return;
      final conversationId = conversation['id'] as String;

      final dogs = await BarkDateUserService.getUserDogs(userId);
      final myDogName = dogs.isNotEmpty
          ? (dogs.first['name'] as String? ?? 'A pup')
          : 'A pup';

      final userRow = await SupabaseConfig.client
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      final humanName = userRow?['name'] as String? ?? 'their human';

      final message = status == 'accepted'
          ? "$myDogName's human, $humanName, joined the walk!"
          : "$myDogName's human, $humanName, can't make it to the walk";

      await ConversationService.postSystemMessage(conversationId, message);
    } catch (e) {
      debugPrint('Error posting walk system message: $e');
    }
  }

  Future<void> _handleResponse(String status) async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.requestId,
        userId: userId,
        response: status,
      );

      if (!mounted) return;

      if (success) {
        ref.invalidate(friendAlertsProvider);
        ref.invalidate(userPlaydatesProvider);

        Map<String, String>? chatTarget;
        Map<String, dynamic>? requestContext;
        requestContext = await _fetchRequestContext();

        if (status == 'accepted') {
          chatTarget = await _resolveAcceptedChatTarget();
          if (!mounted) return;

          if (requestContext != null) {
            final playdateId = (requestContext['playdate_id'] as String?) ?? '';
            if (playdateId.isNotEmpty) {
              await _postWalkSystemMessage(playdateId, userId, status);
              // Sprint 3: removed _showPostAcceptActions. Reminders are now
              // opt-in via ReminderButton on the confirmed-walk card in chat
              // and on the walk-details sheet.
              if (!mounted) return;
            }
          }
        } else if (status == 'declined' && requestContext != null) {
          final playdateId = (requestContext['playdate_id'] as String?) ?? '';
          if (playdateId.isNotEmpty) {
            await _postWalkSystemMessage(playdateId, userId, status);
          }
        }

        if (!mounted) return;
        Navigator.pop(context);

        // After Navigator.pop, this State is being torn down — `context` is
        // about to become stale and `mounted` will flip to false. Use the
        // root navigator's context for any post-close navigation/snackbar so
        // chat actually opens after Accept (was failing silently before).
        // rootNavigatorKey.currentContext outlives modal sheets — safe to
        // use after the pop's async gap.
        final rootCtx = rootNavigatorKey.currentContext;
        if (rootCtx == null) return;

        if (status == 'accepted') {
          if (chatTarget != null) {
            final chatRoute = ChatRoute(
              matchId: chatTarget['conversationId']!,
              recipientId: chatTarget['recipientId']!,
              recipientName: chatTarget['recipientName']!,
              recipientAvatarUrl: chatTarget['recipientAvatarUrl']!,
            );
            // ignore: use_build_context_synchronously
            chatRoute.push(rootCtx);
          }

          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(rootCtx).showSnackBar(
            const SnackBar(
              content: Text('Walk Confirmed! 🎉 Chat is ready.'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (status == 'declined') {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(rootCtx).showSnackBar(
            const SnackBar(
              content: Text('Walk declined.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request status.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt);
    return '${dt.day}/${dt.month} at ${time.format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHandleBar(),
          const SizedBox(height: 24),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.dogPhotoUrl != null
                  ? NetworkImage(widget.dogPhotoUrl!)
                  : null,
              backgroundColor: Colors.grey[200],
              child: widget.dogPhotoUrl == null
                  ? const Icon(Icons.pets, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Walk Invite from ${widget.dogName}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatDateTime(widget.scheduledAt)} • ${widget.location}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ]),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                // Accept
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleResponse('accepted'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE89E5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Yes, let's walk!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),

                // Decline
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _handleResponse('declined'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("Paws are tied right now",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHandleBar() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// Global helper to show the sheet directly given a notification JSON payload.
// Used by the bell-list tap path. The bell-list call site already marks the
// notification as read at the row level — this defensive mark-read is
// belt-and-suspenders, idempotent, and keeps the contract consistent across
// every entry point.
Future<void> showReceiveWalkSheetFromPayload(
    BuildContext context, Map<String, dynamic> data) async {
  final rid = data['request_id'] as String?;
  if (rid == null || rid.isEmpty) return;

  // Sprint 1: defensive mark-as-read by request_id (related_id).
  final uid = SupabaseConfig.auth.currentUser?.id;
  if (uid != null) {
    await NotificationService.markAsReadByRelatedId(
      userId: uid,
      relatedId: rid,
      type: 'playdate_request',
    );
  }

  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReceiveWalkSheet(
      requestId: rid,
      organizerName: data['organizer_name'] ?? 'BarkDate User',
      dogName: data['organizer_dog_name'] ?? 'A dog',
      dogPhotoUrl: data['organizer_dog_photo'] as String?,
      location: data['location'] ?? 'Unknown location',
      scheduledAt: data['scheduled_at'] != null
          ? DateTime.tryParse(data['scheduled_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    ),
  );
}

/// Dedupes rapid double-opens (FCM foreground + DB realtime both firing).
String? _walkInviteSheetDedupeKey;
DateTime? _walkInviteSheetDedupeAt;

/// Opens the walk-invite sheet, resolving [request_id] from the DB when FCM only
/// sends [related_id]/[playdate_id] (common for push payloads).
Future<void> openReceiveWalkSheetFromInvitePayload(
    BuildContext context, Map<String, dynamic> data) async {
  final uid = SupabaseConfig.auth.currentUser?.id;
  if (uid == null) return;

  final dedupeHint =
      (data['request_id'] ?? data['related_id'] ?? data['playdate_id'])
          ?.toString();
  if (dedupeHint != null && dedupeHint.isNotEmpty) {
    final now = DateTime.now();
    if (_walkInviteSheetDedupeKey == dedupeHint &&
        _walkInviteSheetDedupeAt != null &&
        now.difference(_walkInviteSheetDedupeAt!) <
            const Duration(seconds: 4)) {
      return;
    }
  }

  var requestId = data['request_id'] as String?;
  final playdateId = (data['playdate_id'] ?? data['related_id']) as String?;

  if (requestId == null || requestId.isEmpty) {
    if (playdateId != null && playdateId.isNotEmpty) {
      final row = await SupabaseConfig.client
          .from('playdate_requests')
          .select('id')
          .eq('playdate_id', playdateId)
          .eq('invitee_id', uid)
          .eq('status', 'pending')
          .maybeSingle();
      requestId = row?['id'] as String?;
    }
  }

  if (requestId == null || requestId.isEmpty) return;
  final resolvedRequestId = requestId;

  var location = data['location'] as String? ?? 'Unknown location';
  var dogName = data['organizer_dog_name'] as String? ?? 'A dog';
  final dogPhoto = data['organizer_dog_photo'] as String?;
  var organizerName = data['organizer_name'] as String? ?? 'BarkDate User';
  var scheduledAt = data['scheduled_at'] != null
      ? DateTime.tryParse(data['scheduled_at'].toString()) ?? DateTime.now()
      : DateTime.now();

  if (playdateId != null &&
      (data['location'] == null ||
          data['scheduled_at'] == null ||
          dogName == 'A dog')) {
    final pd = await SupabaseConfig.client
        .from('playdates')
        .select('location, scheduled_at, title, organizer:organizer_id(name)')
        .eq('id', playdateId)
        .maybeSingle();
    if (pd != null) {
      location = pd['location'] as String? ?? location;
      scheduledAt = DateTime.tryParse(pd['scheduled_at']?.toString() ?? '') ??
          scheduledAt;
      final org = pd['organizer'] as Map<String, dynamic>?;
      organizerName = org?['name'] as String? ?? organizerName;
    }
  }

  if (!context.mounted) return;
  _walkInviteSheetDedupeKey = resolvedRequestId;
  _walkInviteSheetDedupeAt = DateTime.now();

  // Sprint 1: mark the source notification(s) as read at the funnel entry so
  // this sheet never auto-pops twice for the same invite. We try the most
  // specific identifier first (notification_id from payload), then fall back
  // to related_id matches (request_id and playdate_id) for FCM-tap-from-bg
  // paths that don't carry the local notification id.
  final notifId = data['notification_id'] as String?;
  if (notifId != null && notifId.isNotEmpty) {
    await NotificationService.markAsRead(notifId);
  } else {
    await NotificationService.markAsReadByRelatedId(
      userId: uid,
      relatedId: resolvedRequestId,
      type: 'playdate_request',
    );
    if (playdateId != null && playdateId.isNotEmpty) {
      await NotificationService.markAsReadByRelatedId(
        userId: uid,
        relatedId: playdateId,
        type: 'playdate_request',
      );
    }
  }

  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ReceiveWalkSheet(
      requestId: resolvedRequestId,
      organizerName: organizerName,
      dogName: dogName,
      dogPhotoUrl: dogPhoto,
      location: location,
      scheduledAt: scheduledAt,
    ),
  );
}
