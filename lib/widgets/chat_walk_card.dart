import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/models/friend_alert.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/walk_details_sheet.dart';
import 'package:intl/intl.dart';

/// Effective playdate status for UI labels. Matches [feed_screen] logic: use
/// `playdate_requests` when `playdates.status` lags, and treat multi-participant
/// walks as confirmed when the row is still `pending`.
String effectiveWalkDisplayStatus({
  required Map<String, dynamic> playdateRow,
  required List<Map<String, dynamic>> participants,
}) {
  final ps = (playdateRow['status'] as String?)?.toLowerCase();
  if (ps == 'cancelled') return 'cancelled';

  if (ps == 'confirmed' || ps == 'accepted') return 'confirmed';

  List<dynamic>? requests = playdateRow['requests'] as List<dynamic>?;
  requests ??= playdateRow['playdate_requests'] as List<dynamic>?;

  if (requests != null) {
    for (final r in requests) {
      if (r is Map<String, dynamic>) {
        final rs = (r['status'] as String?)?.toLowerCase();
        if (rs == 'accepted') return 'confirmed';
      }
    }
  }

  if (participants.length >= 2 && (ps == 'pending' || ps == null)) {
    return 'confirmed';
  }

  return ps ?? 'pending';
}

/// Opens [WalkDetailsSheet] for a playdate walk using loaded `playdates` row
/// data (optionally includes embedded `organizer`).
Future<void> openChatWalkDetails(
  BuildContext context, {
  required String playdateId,
  required Map<String, dynamic> playdateData,
  String? fallbackOrganizerName,
}) async {
  final parkName = playdateData['location'] as String? ?? 'Walk Location';
  final scheduledFor =
      DateTime.tryParse(playdateData['scheduled_at'] ?? '') ?? DateTime.now();
  final organizer = playdateData['organizer'] as Map<String, dynamic>?;
  final organizerName = organizer?['name'] as String? ??
      fallbackOrganizerName ??
      'Walk Organizer';
  final lat = (playdateData['latitude'] as num?)?.toDouble();
  final lng = (playdateData['longitude'] as num?)?.toDouble();

  await showWalkDetailsSheet(
    context,
    parkId: parkName,
    parkName: parkName,
    scheduledFor: scheduledFor,
    organizerDogName: organizerName,
    playdateId: playdateId,
    latitude: lat,
    longitude: lng,
  );
}

/// Interactive walk card shown inside chat conversations.
/// Displays walk details (location, time, participants) and allows
/// editing as long as the walk time hasn't passed. Becomes locked after.
class ChatWalkCard extends StatefulWidget {
  final String playdateId;
  final VoidCallback? onUpdated;

  const ChatWalkCard({
    super.key,
    required this.playdateId,
    this.onUpdated,
  });

  @override
  State<ChatWalkCard> createState() => _ChatWalkCardState();
}

class _ChatWalkCardState extends State<ChatWalkCard> {
  Map<String, dynamic>? _playdateData;
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _hasError = false;
  RealtimeChannel? _playdateChannel;

  // Sprint 5: one-shot timer that fires at scheduled_at so the card
  // transitions from "confirmed" to the locked/past pill automatically
  // while the user is still looking at the chat. Re-scheduled whenever
  // _loadPlaydateData runs (handles reschedule + initial load).
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadPlaydateData();
    _subscribeToPlaydateChanges();
  }

  @override
  void dispose() {
    if (_playdateChannel != null) {
      SupabaseConfig.client.removeChannel(_playdateChannel!);
      _playdateChannel = null;
    }
    _expiryTimer?.cancel();
    super.dispose();
  }

  /// Sprint 5: schedule a one-shot Timer that calls setState exactly when
  /// scheduled_at passes, so the next build computes _isExpired = true and
  /// the card transitions to its locked state without user interaction.
  /// 5-second buffer absorbs any client-server clock skew.
  void _scheduleExpiryRebuild() {
    _expiryTimer?.cancel();
    if (_playdateData == null) return;
    final scheduledAtRaw = _playdateData!['scheduled_at'] as String?;
    if (scheduledAtRaw == null) return;
    final scheduledAt = DateTime.tryParse(scheduledAtRaw);
    if (scheduledAt == null) return;

    final delay = scheduledAt.difference(DateTime.now()) +
        const Duration(seconds: 5);
    if (delay.isNegative) return; // already past — build will reflect that

    _expiryTimer = Timer(delay, () {
      if (mounted) setState(() {});
    });
  }

  void _subscribeToPlaydateChanges() {
    _playdateChannel = SupabaseConfig.client
        .channel('chat_walk_card_${widget.playdateId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'playdates',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.playdateId,
          ),
          callback: (payload) {
            if (mounted) _loadPlaydateData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'playdate_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'playdate_id',
            value: widget.playdateId,
          ),
          callback: (payload) {
            if (mounted) _loadPlaydateData();
          },
        )
        .subscribe();
  }

  Future<void> _loadPlaydateData() async {
    try {
      final data = await SupabaseConfig.client.from('playdates').select('''
            *,
            organizer:organizer_id(id, name, avatar_url),
            participants:playdate_participants(
              user_id,
              dog:dog_id(id, name, main_photo_url),
              user:user_id(id, name, avatar_url)
            ),
            requests:playdate_requests(
              id,
              status,
              invitee_id,
              requester_id
            )
          ''').eq('id', widget.playdateId).maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _playdateData = data;
          _participants =
              List<Map<String, dynamic>>.from(data['participants'] ?? []);
          _isLoading = false;
        });
        _scheduleExpiryRebuild();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading playdate for chat card: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  bool get _isExpired {
    if (_playdateData == null) return false;
    final scheduledAt =
        DateTime.tryParse(_playdateData!['scheduled_at'] ?? '') ??
            DateTime.now();
    return DateTime.now().isAfter(scheduledAt);
  }

  bool get _isCancelled {
    return (_playdateData?['status'] as String?)?.toLowerCase() == 'cancelled';
  }

  String get _statusText {
    if (_isCancelled) return 'Cancelled';
    if (_isExpired) return 'Completed';
    final eff = effectiveWalkDisplayStatus(
      playdateRow: _playdateData!,
      participants: _participants,
    );
    switch (eff) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      default:
        if (eff.length > 1) {
          return '${eff[0].toUpperCase()}${eff.substring(1)}';
        }
        return eff;
    }
  }

  bool get _isOrganizer {
    final currentUserId = SupabaseConfig.auth.currentUser?.id;
    if (currentUserId == null || _playdateData == null) return false;
    final organizerId = _playdateData!['organizer_id'] as String?;
    final nestedOrganizer =
        (_playdateData!['organizer'] as Map<String, dynamic>?)?['id'];
    return organizerId == currentUserId || nestedOrganizer == currentUserId;
  }

  String get _ctaLabel {
    final isLocked = _isExpired || _isCancelled;
    if (isLocked) return 'View details';
    return _isOrganizer ? 'Manage walk' : 'View / edit walk';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard(context);
    }

    if (_hasError || _playdateData == null) {
      return const SizedBox.shrink();
    }

    final isLocked = _isExpired || _isCancelled;
    final location = _playdateData!['location'] ?? 'Unknown location';
    final scheduledAt =
        DateTime.tryParse(_playdateData!['scheduled_at'] ?? '') ??
            DateTime.now();

    if (isLocked) {
      final timeStr = _formatDateTime(scheduledAt);
      final statusStr = _statusText;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isCancelled ? Icons.block : Icons.check_circle_outline,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  '$statusStr Walk: $location • $timeStr',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final title = _playdateData!['title'] ?? 'Walk Together';

    final walkBlue = FriendAlert.colorForType(FriendAlertType.walkTogether);
    final surfaceColor = walkBlue;
    final onSurface = Colors.white;
    final onSurfaceMuted = Colors.white.withValues(alpha: 0.85);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isLocked
                      ? Icons.check_circle_outline
                      : FriendAlert.iconForType(FriendAlertType.walkTogether),
                  size: 22,
                  color: onSurface,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.h3(color: onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText,
                    style: AppTypography.labelSmall(color: onSurface).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openLocationOnMap(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 18, color: onSurfaceMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: AppTypography.bodyMedium(
                                color: onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.directions_outlined,
                              color: onSurfaceMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openWalkDetails(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 18, color: onSurfaceMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatDateTime(scheduledAt),
                              style: AppTypography.bodyMedium(
                                color: onSurfaceMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_participants.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: (_participants.length.clamp(1, 5) * 22) + 10,
                        height: 32,
                        child: Stack(
                          children: _participants
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            final idx = entry.key;
                            final participant = entry.value;
                            final dog =
                                participant['dog'] as Map<String, dynamic>?;
                            final photoUrl = dog?['main_photo_url'] as String?;

                            return Positioned(
                              left: idx * 22.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: onSurface, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  backgroundColor: Colors.white24,
                                  child: photoUrl == null
                                      ? Icon(Icons.pets,
                                          size: 14, color: onSurfaceMuted)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_participants.length} ${_participants.length == 1 ? 'participant' : 'participants'}',
                          style: AppTypography.bodySmall(color: onSurfaceMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openWalkDetails(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.white,
                  foregroundColor: isLocked ? Colors.grey.shade700 : walkBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  _ctaLabel,
                  style: AppTypography.labelMedium(
                    color: isLocked ? Colors.grey.shade700 : walkBlue,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading walk details...',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    String dayPart;
    if (dateOnly == today) {
      dayPart = 'Today';
    } else if (dateOnly == tomorrow) {
      dayPart = 'Tomorrow';
    } else {
      dayPart = DateFormat('EEE, MMM d').format(dt);
    }

    return '$dayPart at ${DateFormat('h:mm a').format(dt)}';
  }

  Future<void> _openWalkDetails(BuildContext context) async {
    if (_playdateData == null) return;

    await openChatWalkDetails(
      context,
      playdateId: widget.playdateId,
      playdateData: _playdateData!,
    );

    if (mounted) {
      _loadPlaydateData();
      widget.onUpdated?.call();
    }
  }

  /// Open the walk location in the in-app map or offer external directions.
  Future<void> _openLocationOnMap(BuildContext context) async {
    if (_playdateData == null) return;

    final lat = (_playdateData!['latitude'] as num?)?.toDouble();
    final lng = (_playdateData!['longitude'] as num?)?.toDouble();
    final location = _playdateData!['location'] as String? ?? 'Location';

    if (lat != null && lng != null) {
      // Offer directions via external maps app
      final encodedName = Uri.encodeComponent(location);
      final googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$encodedName';
      final appleMapsUrl = 'https://maps.apple.com/?daddr=$lat,$lng&dirflg=w';

      if (!context.mounted) return;

      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.directions_walk,
                      color: Color(0xFF0D47A1)),
                  title: const Text('Get Directions (Google Maps)'),
                  onTap: () => Navigator.pop(ctx, 'google'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.map_outlined, color: Color(0xFF0D47A1)),
                  title: const Text('Get Directions (Apple Maps)'),
                  onTap: () => Navigator.pop(ctx, 'apple'),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: Color(0xFF0D47A1)),
                  title: const Text('View Walk Details'),
                  onTap: () => Navigator.pop(ctx, 'details'),
                ),
              ],
            ),
          ),
        ),
      );

      if (choice == null || !context.mounted) return;

      switch (choice) {
        case 'google':
          await launchUrl(Uri.parse(googleMapsUrl),
              mode: LaunchMode.externalApplication);
          break;
        case 'apple':
          await launchUrl(Uri.parse(appleMapsUrl),
              mode: LaunchMode.externalApplication);
          break;
        case 'details':
          await _openWalkDetails(context);
          break;
      }
    } else {
      // No coordinates — just open walk details
      await _openWalkDetails(context);
    }
  }
}

/// Compact pinned header bar shown at the top of a walk chat.
/// Always visible — shows location, time, and status at a glance.
class ChatWalkPinnedHeader extends StatelessWidget {
  final String playdateId;
  final String location;
  final DateTime scheduledFor;
  final String status;
  final VoidCallback? onTap;

  const ChatWalkPinnedHeader({
    super.key,
    required this.playdateId,
    required this.location,
    required this.scheduledFor,
    required this.status,
    this.onTap,
  });

  bool get _isExpired => DateTime.now().isAfter(scheduledFor);
  bool get _isCancelled => status == 'cancelled';
  bool get _isLocked => _isExpired || _isCancelled;

  String get _statusText {
    if (_isCancelled) return 'Cancelled';
    if (_isExpired) return 'Completed';
    final s = status.toLowerCase();
    switch (s) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      default:
        if (status.length > 1) {
          return '${status[0].toUpperCase()}${status.substring(1)}';
        }
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(scheduledFor);
    final walkBlue = FriendAlert.colorForType(FriendAlertType.walkTogether);
    final bg = _isLocked ? Colors.grey.shade600 : walkBlue;
    const fg = Colors.white;
    final fgMuted = Colors.white.withValues(alpha: 0.85);

    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _isLocked ? Icons.lock_outline : Icons.location_on_outlined,
                size: 18,
                color: fgMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      style: AppTypography.bodyMedium(color: fg).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: AppTypography.bodySmall(color: fgMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusText,
                  style: AppTypography.labelSmall(color: fg).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: fgMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    if (dateOnly == today) {
      return 'Today ${DateFormat('h:mm a').format(dt)}';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }
}
