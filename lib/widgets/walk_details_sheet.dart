import 'package:flutter/material.dart';
import 'package:barkdate/services/friend_activity_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/services/conversation_service.dart';
import 'package:barkdate/services/places_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/barkdate_services.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/features/playdates/presentation/screens/map_picker_screen.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:barkdate/widgets/reminder_button.dart';

/// Bottom sheet showing details of a planned walk — who's going, time, park.
/// Supports both checkin-based walks (System B) and playdate-based walks (System A).
/// When playdateId is provided, loads from the playdates table and enables
/// chat navigation and playdate-style join/cancel.
class WalkDetailsSheet extends StatefulWidget {
  final String parkId;
  final String parkName;
  final DateTime scheduledFor;
  final String organizerDogName;
  final String? checkInId;
  final String? playdateId;
  final double? latitude;
  final double? longitude;

  const WalkDetailsSheet({
    super.key,
    required this.parkId,
    required this.parkName,
    required this.scheduledFor,
    required this.organizerDogName,
    this.checkInId,
    this.playdateId,
    this.latitude,
    this.longitude,
  });

  bool get _isPlaydateBased => playdateId != null && playdateId!.isNotEmpty;

  @override
  State<WalkDetailsSheet> createState() => _WalkDetailsSheetState();
}

class _WalkDetailsSheetState extends State<WalkDetailsSheet> {
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isJoining = false;
  bool _hasJoined = false;
  bool _isOrganizer = false;
  String? _conversationId;
  Map<String, dynamic>? _playdateData;
  bool _isUpdatingPlace = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget._isPlaydateBased) {
      await _loadPlaydateData();
    } else {
      await _loadCheckinParticipants();
    }
  }

  Future<void> _loadPlaydateData() async {
    try {
      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      final pid = widget.playdateId!;

      final playdateFuture = SupabaseConfig.client
          .from('playdates')
          .select('*, organizer:organizer_id(id, name, avatar_url)')
          .eq('id', pid)
          .maybeSingle();
      final participantsFuture =
          FriendActivityService.getPlaydateWalkParticipants(pid);
      final conversationFuture =
          ConversationService.getPlaydateConversation(pid);

      final results = await Future.wait<dynamic>(
          [playdateFuture, participantsFuture, conversationFuture]);

      final playdateResult = results[0] as Map<String, dynamic>?;
      final participants =
          results[1] as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[];
      final conversation = results[2] as Map<String, dynamic>?;

      final joined = participants.any((p) => p['user_id'] == currentUserId);
      final rawOrganizerId = playdateResult?['organizer_id'];
      final nestedOrganizerId =
          (playdateResult?['organizer'] as Map<String, dynamic>?)?['id'];
      final isOrg =
          rawOrganizerId == currentUserId || nestedOrganizerId == currentUserId;

      if (mounted) {
        setState(() {
          _playdateData = playdateResult;
          _participants = participants;
          _isLoading = false;
          _hasJoined = joined || isOrg;
          _isOrganizer = isOrg;
          _conversationId = conversation?['id'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading playdate walk data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCheckinParticipants() async {
    try {
      final participants = await FriendActivityService.getWalkParticipants(
        widget.parkId,
        widget.scheduledFor,
      );

      final currentUserId = SupabaseConfig.auth.currentUser?.id;
      final joined = participants.any((p) => p['user_id'] == currentUserId);

      if (mounted) {
        setState(() {
          _participants = participants;
          _isLoading = false;
          _hasJoined = joined;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinWalk() async {
    setState(() => _isJoining = true);

    try {
      if (widget._isPlaydateBased) {
        await _joinPlaydateWalk();
      } else {
        await _joinCheckinWalk();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _joinPlaydateWalk() async {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (currentUserId == null) return;

    final dogs = await BarkDateUserService.getUserDogs(currentUserId);
    if (dogs.isEmpty) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create a dog profile first')),
        );
      }
      return;
    }

    final dogId = dogs.first['id'] as String;

    try {
      await SupabaseConfig.client.from('playdate_participants').insert({
        'playdate_id': widget.playdateId,
        'user_id': currentUserId,
        'dog_id': dogId,
      });
    } catch (e) {
      if (e.toString().contains('duplicate key')) {
        // Already joined
      } else {
        rethrow;
      }
    }

    await ConversationService.ensurePlaydateParticipant(
      playdateId: widget.playdateId!,
      userId: currentUserId,
    );

    if (!mounted) return;

    setState(() {
      _hasJoined = true;
      _isJoining = false;
    });
    _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You joined the walk at ${widget.parkName}!'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _joinCheckinWalk() async {
    final success = await FriendActivityService.joinScheduledWalk(
      parkId: widget.parkId,
      parkName: widget.parkName,
      scheduledFor: widget.scheduledFor,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _hasJoined = true;
        _isJoining = false;
      });
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You joined the walk at ${widget.parkName}!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancelMyJoin() async {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (currentUserId == null) return;

    setState(() => _isJoining = true);

    try {
      if (widget._isPlaydateBased) {
        await SupabaseConfig.client
            .from('playdate_participants')
            .delete()
            .eq('playdate_id', widget.playdateId!)
            .eq('user_id', currentUserId);

        await ConversationService.removePlaydateParticipant(
          playdateId: widget.playdateId!,
          userId: currentUserId,
        );
      } else {
        final myCheckIn = _participants.firstWhere(
          (p) => p['user_id'] == currentUserId,
          orElse: () => {},
        );
        if (myCheckIn.isNotEmpty && myCheckIn['id'] != null) {
          await CheckInService.cancelScheduledCheckIn(myCheckIn['id']);
        }
      }

      if (mounted) {
        setState(() {
          _hasJoined = false;
          _isJoining = false;
        });
        _loadData();
      }
    } catch (e) {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _changePlace() async {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (currentUserId == null ||
        widget.playdateId == null ||
        !widget._isPlaydateBased ||
        !_isOrganizer) {
      return;
    }

    final isExpired = DateTime.now().isAfter(widget.scheduledFor);
    final isCancelled = _playdateData?['status'] == 'cancelled';
    if (isExpired || isCancelled) return;

    final PlaceResult? result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (context) => const MapPickerScreen(),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isUpdatingPlace = true);
    try {
      final locationText = result.name.trim().isNotEmpty
          ? result.name.trim()
          : result.address.trim();
      final ok = await PlaydateRequestService.updatePlaydateLocation(
        playdateId: widget.playdateId!,
        userId: currentUserId,
        location: locationText,
        latitude: result.latitude,
        longitude: result.longitude,
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the organizer can change the place.'),
          ),
        );
        return;
      }
      await _loadPlaydateData();
      if (_conversationId != null) {
        await ConversationService.postSystemMessage(
          _conversationId!,
          'Walk location updated to $locationText',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update place: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingPlace = false);
    }
  }

  void _openChat() {
    if (_conversationId == null || _playdateData == null) return;
    final organizer = _playdateData!['organizer'] as Map<String, dynamic>?;
    Navigator.of(context).pop();
    ChatRoute(
      matchId: _conversationId!,
      recipientId: organizer?['id'] as String? ?? '',
      recipientName: _playdateData!['title'] as String? ?? 'Walk Chat',
      recipientAvatarUrl: organizer?['avatar_url'] as String? ?? '',
    ).push(context);
  }

  @override
  Widget build(BuildContext context) {
    final hour = widget.scheduledFor.hour;
    final minute = widget.scheduledFor.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$displayHour:$minute $amPm';

    final isExpired = DateTime.now().isAfter(widget.scheduledFor);
    final isCancelled = _playdateData?['status'] == 'cancelled';
    final isLocked = isExpired || isCancelled;
    final displayLocation =
        _playdateData?['location'] as String? ?? widget.parkName;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLocked ? Colors.grey.shade400 : const Color(0xFF0D47A1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked
                      ? (isCancelled ? Icons.block : Icons.check_circle_outline)
                      : Icons.schedule_outlined,
                  size: 32,
                  color: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLocked
                            ? (isCancelled
                                ? 'Walk Cancelled'
                                : 'Walk Completed')
                            : 'Walk Together',
                        style: AppTypography.h3(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$displayLocation at $timeStr',
                        style: AppTypography.bodySmall(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Organized by
          Text(
            'Organized by',
            style: AppTypography.labelMedium(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.pets,
                      size: 18, color: const Color(0xFF0D47A1)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isOrganizer ? 'You' : widget.organizerDogName,
                style: AppTypography.bodyLarge(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isOrganizer)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Organizer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
            ],
          ),

          if (widget._isPlaydateBased && _isOrganizer && !isLocked) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Place',
              style: AppTypography.labelMedium(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    displayLocation,
                    style: AppTypography.bodyLarge(),
                  ),
                ),
                TextButton(
                  onPressed: _isUpdatingPlace ? null : _changePlace,
                  child: _isUpdatingPlace
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change place'),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Participants
          Text(
            _isLoading
                ? 'Who\'s joining'
                : 'Who\'s joining (${_participants.length})',
            style: AppTypography.labelMedium(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_participants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No one else has joined yet — be the first!',
                  style: AppTypography.bodySmall(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ...(_participants.take(5).map((p) {
              final dog = p['dog'] as Map<String, dynamic>?;
              final user = p['user'] as Map<String, dynamic>?;
              final dogName = dog?['name'] ?? 'A dog';
              final photoUrl = dog?['main_photo_url'] as String?;
              final ownerName = user?['name'] as String?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                        image: photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(photoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: photoUrl == null
                          ? const Center(
                              child: Icon(Icons.pets,
                                  size: 16, color: Colors.grey))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dogName,
                            style: AppTypography.bodyMedium(),
                          ),
                          if (ownerName != null)
                            Text(
                              'with $ownerName',
                              style: AppTypography.bodySmall(
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })),

          if (_participants.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '+${_participants.length - 5} more',
                style: AppTypography.bodySmall(color: Colors.grey[500]),
              ),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Open Chat button (only for playdate-based walks with a conversation)
          if (_conversationId != null && !isLocked) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Open Walk Chat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Sprint 3: Reminder button (opt-in). Shown only for playdate-based
          // walks (we need a playdate_id for the upsert) that aren't locked or
          // already in the past — there's no point reminding about a finished
          // walk.
          if (widget._isPlaydateBased &&
              !isLocked &&
              widget.scheduledFor.isAfter(DateTime.now())) ...[
            ReminderButton(
              playdateId: widget.playdateId!,
              scheduledAt: widget.scheduledFor,
              walkTitle: (_playdateData?['title'] as String?) ??
                  'Walk at ${widget.parkName}',
              walkLocation: widget.parkName,
              compact: false,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Join / Cancel button (hidden when locked)
          if (!isLocked)
            SizedBox(
              width: double.infinity,
              child: _hasJoined && !_isOrganizer
                  ? OutlinedButton(
                      onPressed: _isJoining ? null : _cancelMyJoin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : Text(
                              'Leave This Walk',
                              style: AppTypography.button(color: Colors.red),
                            ),
                    )
                  : !_hasJoined
                      ? ElevatedButton.icon(
                          onPressed: _isJoining ? null : _joinWalk,
                          icon: const Icon(Icons.pets, size: 18),
                          label: _isJoining
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Join the Walk',
                                  style:
                                      AppTypography.button(color: Colors.white),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Show the Walk Details bottom sheet
Future<void> showWalkDetailsSheet(
  BuildContext context, {
  required String parkId,
  required String parkName,
  required DateTime scheduledFor,
  required String organizerDogName,
  String? checkInId,
  String? playdateId,
  double? latitude,
  double? longitude,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WalkDetailsSheet(
      parkId: parkId,
      parkName: parkName,
      scheduledFor: scheduledFor,
      organizerDogName: organizerDogName,
      checkInId: checkInId,
      playdateId: playdateId,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}
