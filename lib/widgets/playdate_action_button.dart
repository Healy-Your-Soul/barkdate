import 'package:flutter/material.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/widgets/app_button.dart';

/// High‑level adaptive playdate action button.
/// Displays one of:
///  - Request Playdate
///  - Pending (sent)
///  - Accept / Decline (if incoming)
///  - Edit / Reschedule / Cancel (if confirmed)
/// (This is a simplified reconstruction – can be expanded with more granular states.)
class PlaydateActionButton extends StatefulWidget {
  /// Backward compatibility: an existing code path may pass an entire playdate map.
  /// If provided, explicit target/ dog IDs become optional. Provide either:
  ///  (A) playdate (with organizer_id / participant_id) OR
  ///  (B) targetUserId + targetDogId + myDogId
  final Map<String, dynamic>? playdate;
  final String? targetUserId; // Owner of the other dog
  final String? targetDogId;
  final String? myDogId; // Current user's selected dog
  final void Function(String playdateId)? onCreated;
  final EdgeInsets padding;

  const PlaydateActionButton({
    super.key,
    this.playdate,
    this.targetUserId,
    this.targetDogId,
    this.myDogId,
    this.onCreated,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  }) : assert(
          playdate != null ||
              (targetUserId != null && targetDogId != null && myDogId != null),
          'Provide either playdate or explicit user/dog IDs',
        );

  @override
  State<PlaydateActionButton> createState() => _PlaydateActionButtonState();
}

class _PlaydateActionButtonState extends State<PlaydateActionButton> {
  bool _loading = true;
  String _state =
      'none'; // none | pending_outgoing | pending_incoming | confirmed
  Map<String, dynamic>? _playdate; // confirmed playdate or request container
  String? _requestId; // pending request id if exists

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      setState(() {
        _state = 'none';
        _loading = false;
      });
      return;
    }

    // If a full playdate map passed in and it's confirmed, just render confirmed state.
    if (widget.playdate != null) {
      final status = widget.playdate!['status'];
      if (status == 'confirmed') {
        setState(() {
          _playdate = widget.playdate;
          _state = 'confirmed';
          _loading = false;
        });
        return;
      }
    }

    final targetUserId = widget.targetUserId ?? _deriveTargetUserId(user.id);
    if (targetUserId == null) {
      setState(() {
        _state = 'none';
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final myId = user.id;
      // Confirmed playdate check
      final confirmed = await SupabaseConfig.client
          .from('playdates')
          .select(
              'id, title, location, scheduled_at, status, organizer_id, participant_id')
          .or('organizer_id.eq.$myId,participant_id.eq.$myId')
          .neq('status', 'cancelled')
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .limit(8);

      Map<String, dynamic>? foundConfirmed;
      for (final p in confirmed) {
        final between = (p['organizer_id'] == myId &&
                p['participant_id'] == targetUserId) ||
            (p['organizer_id'] == targetUserId && p['participant_id'] == myId);
        if (between && p['status'] == 'confirmed') {
          foundConfirmed = p;
          break;
        }
      }
      if (foundConfirmed != null) {
        setState(() {
          _state = 'confirmed';
          _playdate = foundConfirmed;
          _loading = false;
        });
        return;
      }

      // Outgoing pending
      final outgoing = await SupabaseConfig.client
          .from('playdate_requests')
          .select('id, requester_id, invitee_id, status')
          .eq('requester_id', myId)
          .eq('invitee_id', targetUserId)
          .eq('status', 'pending')
          .limit(1);
      if (outgoing.isNotEmpty) {
        setState(() {
          _state = 'pending_outgoing';
          _requestId = outgoing.first['id'];
          _loading = false;
        });
        return;
      }

      // Incoming pending
      final incoming = await SupabaseConfig.client
          .from('playdate_requests')
          .select('id, requester_id, invitee_id, status')
          .eq('invitee_id', myId)
          .eq('requester_id', targetUserId)
          .eq('status', 'pending')
          .limit(1);
      if (incoming.isNotEmpty) {
        setState(() {
          _state = 'pending_incoming';
          _requestId = incoming.first['id'];
          _loading = false;
        });
        return;
      }

      setState(() {
        _state = 'none';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = 'none';
          _loading = false;
        });
      }
    }
  }

  String? _deriveTargetUserId(String currentUserId) {
    if (widget.playdate == null) return null;
    final organizer = widget.playdate!['organizer_id'];
    final participant = widget.playdate!['participant_id'];
    if (organizer == currentUserId) return participant;
    if (participant == currentUserId) return organizer;
    return organizer ?? participant; // fallback
  }

  Future<void> _createRequest() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;
    DateTime scheduled = DateTime.now().add(const Duration(days: 1));

    // Ensure we have required non-null values
    final myDogId = widget.myDogId;
    final targetUserId = widget.targetUserId;
    final targetDogId = widget.targetDogId;

    if (myDogId == null || targetUserId == null || targetDogId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing required information')),
      );
      return;
    }

    final playdateId = await PlaydateRequestService.createPlaydateRequest(
        organizerId: user.id,
        organizerDogId: myDogId,
        inviteeId: targetUserId,
        inviteeDogId: targetDogId,
        title: 'Playdate',
        location: 'Local Park',
        scheduledAt: scheduled,
        description: 'Let our dogs meet!');
    if (playdateId != null) {
      widget.onCreated?.call(playdateId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request sent')));
      }
      _refresh();
    }
  }

  Future<void> _accept() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null || _requestId == null) return;
    await PlaydateRequestService.respondToPlaydateRequest(
      requestId: _requestId!,
      userId: user.id,
      response: 'accepted',
      message: 'See you there!',
    );
    _refresh();
  }

  Future<void> _decline() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null || _requestId == null) return;
    await PlaydateRequestService.respondToPlaydateRequest(
      requestId: _requestId!,
      userId: user.id,
      response: 'declined',
      message: 'Maybe another time.',
    );
    _refresh();
  }

  Future<void> _cancelOutgoing() async {
    if (_requestId == null) return;
    await PlaydateRequestService.cancelRequest(_requestId!);
    _refresh();
  }

  Future<void> _showConfirmedSheet() async {
    if (_playdate == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Playdate Scheduled',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                  '${_playdate!['location'] ?? 'Location TBD'} • ${_playdate!['scheduled_at'].toString()}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.update),
                      label: const Text('Reschedule'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rescheduleDialog();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon:
                          const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Cancel'),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cancel playdate?'),
                            content: const Text(
                                'Other participant(s) will be notified.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Keep')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Cancel')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await PlaydateManagementService.cancelPlaydate(
                            playdateId: _playdate!['id'],
                            cancelledByUserId:
                                SupabaseConfig.auth.currentUser!.id,
                          );
                          _refresh();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rescheduleDialog() async {
    if (_playdate == null) return;
    DateTime current = DateTime.parse(_playdate!['scheduled_at']);
    DateTime? pickedDate = current;
    TimeOfDay? pickedTime = TimeOfDay.fromDateTime(current);
    final locationCtrl =
        TextEditingController(text: _playdate!['location'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Reschedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(pickedDate == null
                      ? 'Pick date'
                      : '${pickedDate!.year}-${pickedDate!.month}-${pickedDate!.day}'),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) setLocal(() => pickedDate = d);
                  },
                ),
                ListTile(
                  title: Text(pickedTime == null
                      ? 'Pick time'
                      : pickedTime!.format(ctx)),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx,
                        initialTime: pickedTime ?? TimeOfDay.now());
                    if (t != null) setLocal(() => pickedTime = t);
                  },
                ),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (pickedDate != null && pickedTime != null) {
                  final newDt = DateTime(pickedDate!.year, pickedDate!.month,
                      pickedDate!.day, pickedTime!.hour, pickedTime!.minute);
                  await PlaydateManagementService.reschedulePlaydate(
                    playdateId: _playdate!['id'],
                    updatedByUserId: SupabaseConfig.auth.currentUser!.id,
                    newScheduledAt: newDt,
                    newLocation:
                        locationCtrl.text.isEmpty ? null : locationCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refresh();
                }
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: widget.padding,
        child: const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    switch (_state) {
      case 'pending_outgoing':
        return Padding(
          padding: widget.padding,
          child: AppButton(
            text: 'Pending',
            icon: Icons.hourglass_bottom,
            type: AppButtonType.outline,
            onPressed: _cancelOutgoing,
          ),
        );
      case 'pending_incoming':
        return Padding(
          padding: widget.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                text: 'Accept',
                onPressed: _accept,
              ),
              const SizedBox(width: 8),
              AppButton(
                text: 'Decline',
                type: AppButtonType.outline,
                onPressed: _decline,
              ),
            ],
          ),
        );
      case 'confirmed':
        return Padding(
          padding: widget.padding,
          child: AppButton(
            text: 'Scheduled',
            icon: Icons.event_available,
            customColor: Colors.green,
            onPressed: _showConfirmedSheet,
          ),
        );
      default:
        return Padding(
          padding: widget.padding,
          child: AppButton(
            text: 'Playdate',
            icon: Icons.calendar_today,
            type: AppButtonType.outline,
            onPressed: _createRequest,
          ),
        );
    }
  }
}
