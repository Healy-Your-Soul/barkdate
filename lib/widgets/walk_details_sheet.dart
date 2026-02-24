import 'package:flutter/material.dart';
import 'package:barkdate/services/friend_activity_service.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Bottom sheet showing details of a planned walk — who's going, time, park.
/// Includes a "Join the Walk" button for friends.
class WalkDetailsSheet extends StatefulWidget {
  final String parkId;
  final String parkName;
  final DateTime scheduledFor;
  final String organizerDogName;
  final String? checkInId;
  final double? latitude;
  final double? longitude;

  const WalkDetailsSheet({
    super.key,
    required this.parkId,
    required this.parkName,
    required this.scheduledFor,
    required this.organizerDogName,
    this.checkInId,
    this.latitude,
    this.longitude,
  });

  @override
  State<WalkDetailsSheet> createState() => _WalkDetailsSheetState();
}

class _WalkDetailsSheetState extends State<WalkDetailsSheet> {
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isJoining = false;
  bool _hasJoined = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      final participants = await FriendActivityService.getWalkParticipants(
        widget.parkId,
        widget.scheduledFor,
      );

      // Check if current user has already joined
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinWalk() async {
    setState(() => _isJoining = true);

    try {
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
        // Reload participants
        _loadParticipants();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🐕 You joined the walk at ${widget.parkName}!'),
            backgroundColor: const Color(0xFF0D47A1),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

  Future<void> _cancelMyJoin() async {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Find the user's check-in
    final myCheckIn = _participants.firstWhere(
      (p) => p['user_id'] == currentUserId,
      orElse: () => {},
    );
    if (myCheckIn.isEmpty || myCheckIn['id'] == null) return;

    setState(() => _isJoining = true);

    try {
      await CheckInService.cancelScheduledCheckIn(myCheckIn['id']);
      if (mounted) {
        setState(() {
          _hasJoined = false;
          _isJoining = false;
        });
        _loadParticipants();
      }
    } catch (e) {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = widget.scheduledFor.hour;
    final minute = widget.scheduledFor.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$displayHour:$minute $amPm';

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
              color: const Color(0xFF0D47A1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🕐', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Walk Together',
                        style: AppTypography.h3(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.parkName} at $timeStr',
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
                child: const Center(
                  child: Text('🐕', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.organizerDogName,
                style: AppTypography.bodyLarge(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Participants
          Text(
            'Who\'s joining (${_participants.length})',
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
              final dogName = dog?['name'] ?? 'A dog';
              final photoUrl = dog?['main_photo_url'] as String?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Avatar
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
                              child: Text('🐶',
                                  style: TextStyle(fontSize: 16)))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dogName,
                      style: AppTypography.bodyMedium(),
                    ),
                  ],
                ),
              );
            })),

          const SizedBox(height: AppSpacing.xxl),

          // Join / Cancel button
          SizedBox(
            width: double.infinity,
            child: _hasJoined
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
                            'Cancel My Walk',
                            style: AppTypography.button(color: Colors.red),
                          ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isJoining ? null : _joinWalk,
                    icon: const Text('🐕', style: TextStyle(fontSize: 18)),
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
                            style: AppTypography.button(color: Colors.white),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Show the Walk Details bottom sheet
void showWalkDetailsSheet(
  BuildContext context, {
  required String parkId,
  required String parkName,
  required DateTime scheduledFor,
  required String organizerDogName,
  String? checkInId,
  double? latitude,
  double? longitude,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WalkDetailsSheet(
      parkId: parkId,
      parkName: parkName,
      scheduledFor: scheduledFor,
      organizerDogName: organizerDogName,
      checkInId: checkInId,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}
