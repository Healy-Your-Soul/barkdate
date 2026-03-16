import 'package:flutter/material.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/services/calendar_integration_service.dart';
import 'package:barkdate/core/router/app_routes.dart';

class ReceiveWalkSheet extends StatefulWidget {
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
  State<ReceiveWalkSheet> createState() => _ReceiveWalkSheetState();
}

class _ReceiveWalkSheetState extends State<ReceiveWalkSheet> {
  bool _isLoading = false;
  final TextEditingController _counterLocationController =
      TextEditingController();

  @override
  void dispose() {
    _counterLocationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchRequestContext() async {
    try {
      final request = await SupabaseConfig.client
          .from('playdate_requests')
          .select('''
            id,
            playdate_id,
            playdate:playdates(id, title, location, scheduled_at)
          ''')
          .eq('id', widget.requestId)
          .maybeSingle();

      if (request == null) return null;
      return Map<String, dynamic>.from(request);
    } catch (e) {
      debugPrint('Could not fetch request context: $e');
      return null;
    }
  }

  Future<Map<String, String>?> _resolveAcceptedChatTarget() async {
    try {
      final request = await SupabaseConfig.client
          .from('playdate_requests')
          .select('''
            playdate_id,
            requester_id,
            requester:users!playdate_requests_requester_id_fkey(name, avatar_url)
          ''')
          .eq('id', widget.requestId)
          .maybeSingle();

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
        'recipientName': (requester?['name'] as String?) ?? widget.organizerName,
        'recipientAvatarUrl': (requester?['avatar_url'] as String?) ?? '',
      };
    } catch (e) {
      debugPrint('Could not resolve accepted chat target: $e');
      return null;
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
        Map<String, String>? chatTarget;
        Map<String, dynamic>? requestContext;
        if (status == 'accepted') {
          requestContext = await _fetchRequestContext();
          chatTarget = await _resolveAcceptedChatTarget();
          if (!mounted) return;

          if (requestContext != null) {
            final playdate =
                requestContext['playdate'] as Map<String, dynamic>? ?? const {};
            final playdateId = (requestContext['playdate_id'] as String?) ?? '';
            if (playdateId.isNotEmpty) {
              await _showPostAcceptActions(
                userId: userId,
                playdateId: playdateId,
                title: (playdate['title'] as String?) ??
                    'Walk with ${widget.dogName}',
                location: (playdate['location'] as String?) ?? widget.location,
                scheduledAt: (playdate['scheduled_at'] as String?) != null
                    ? DateTime.tryParse(playdate['scheduled_at']) ??
                        widget.scheduledAt
                    : widget.scheduledAt,
              );
              if (!mounted) return;
            }
          }
        }

        Navigator.pop(context); // Close sheet

        if (status == 'accepted') {
          if (chatTarget != null && mounted) {
            ChatRoute(
              matchId: chatTarget['conversationId']!,
              recipientId: chatTarget['recipientId']!,
              recipientName: chatTarget['recipientName']!,
              recipientAvatarUrl: chatTarget['recipientAvatarUrl']!,
            ).push(context);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Walk Confirmed! 🎉 Chat is ready.'),
              backgroundColor: Color(0xFFE89E5F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (status == 'declined') {
          ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _handleMaybeLater() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        DateTime selectedDate = widget.scheduledAt;
        TimeOfDay selectedTime = TimeOfDay.fromDateTime(widget.scheduledAt);

        return StatefulBuilder(
          builder: (context, setState) {
            final proposedDateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );

            return AlertDialog(
              title: const Text('Suggest a better time'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _counterLocationController,
                      decoration: const InputDecoration(
                        labelText: 'Optional location note',
                        hintText: 'Same park, but near the south gate',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Proposed time'),
                      subtitle: Text(_formatDateTime(proposedDateTime)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 180)),
                        );
                        if (date == null || !context.mounted) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time == null) return;

                        setState(() {
                          selectedDate = date;
                          selectedTime = time;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'scheduled_at': proposedDateTime.toIso8601String(),
                      'location_note': _counterLocationController.text.trim(),
                    });
                  },
                  child: const Text('Send proposal'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseConfig.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final success = await PlaydateRequestService.respondToPlaydateRequest(
        requestId: widget.requestId,
        userId: userId,
        response: 'counter_proposed',
        message: 'Could we adjust the plan a bit?',
        counterProposal: {
          'scheduled_at': result['scheduled_at'],
          if ((result['location_note'] as String).isNotEmpty)
            'location_note': result['location_note'],
        },
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send counter-proposal.')),
        );
        return;
      }

      final chatTarget = await _resolveAcceptedChatTarget();
      if (!mounted) return;
      Navigator.pop(context);

      if (chatTarget != null && mounted) {
        ChatRoute(
          matchId: chatTarget['conversationId']!,
          recipientId: chatTarget['recipientId']!,
          recipientName: chatTarget['recipientName']!,
          recipientAvatarUrl: chatTarget['recipientAvatarUrl']!,
        ).push(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Counter-proposal sent. Continue in chat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _showPostAcceptActions({
    required String userId,
    required String playdateId,
    required String title,
    required String location,
    required DateTime scheduledAt,
  }) async {
    int? selectedMinutes;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> saveAndClose() async {
              if (selectedMinutes != null) {
                await PlaydateRequestService.upsertReminderPreference(
                  userId: userId,
                  playdateId: playdateId,
                  requestId: widget.requestId,
                  minutesBefore: selectedMinutes!,
                );
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            }

            Future<void> addToCalendar() async {
              final ok = await CalendarIntegrationService.addPlaydateToCalendar(
                title: title,
                startTime: scheduledAt,
                endTime: scheduledAt.add(const Duration(minutes: 60)),
                location: location,
                description: 'Planned with BarkDate',
              );

              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Opening calendar event draft...'
                      : 'Could not open calendar right now.'),
                ),
              );
            }

            Widget chip(String label, int minutes) {
              final selected = selectedMinutes == minutes;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => selectedMinutes = minutes),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional reminder',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        chip('15 min', 15),
                        chip('1 hour', 60),
                        chip('1 day', 1440),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: addToCalendar,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Add to calendar'),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saveAndClose,
                        child: const Text('Continue to chat'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

                // Maybe Later
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _handleMaybeLater,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFE89E5F)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Maybe later",
                        style: TextStyle(
                            color: Color(0xFFE89E5F),
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
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

// Global helper to show the sheet directly given a notification JSON payload
void showReceiveWalkSheetFromPayload(
    BuildContext context, Map<String, dynamic> data) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReceiveWalkSheet(
      requestId: data['request_id'] ??
          data['playdate_id'] ??
          '', // Prefer request_id if available
      organizerName: data['organizer_name'] ?? 'BarkDate User',
      dogName: data['organizer_dog_name'] ?? 'A dog',
      location: data['location'] ?? 'Unknown location',
      scheduledAt: data['scheduled_at'] != null
          ? DateTime.tryParse(data['scheduled_at']) ?? DateTime.now()
          : DateTime.now(),
    ),
  );
}
