import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/walk_details_sheet.dart';
import 'package:intl/intl.dart';

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
    super.dispose();
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
        .subscribe();
  }

  Future<void> _loadPlaydateData() async {
    try {
      final data = await SupabaseConfig.client
          .from('playdates')
          .select('''
            *,
            organizer:organizer_id(id, name, avatar_url),
            participants:playdate_participants(
              user_id,
              dog:dog_id(id, name, main_photo_url),
              user:user_id(id, name, avatar_url)
            )
          ''')
          .eq('id', widget.playdateId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _playdateData = data;
          _participants = List<Map<String, dynamic>>.from(
              data['participants'] ?? []);
          _isLoading = false;
        });
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
    return _playdateData?['status'] == 'cancelled';
  }

  String get _statusText {
    if (_isCancelled) return 'Cancelled';
    if (_isExpired) return 'Completed';
    final status = _playdateData?['status'] ?? 'pending';
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      default:
        return status.toString().replaceFirst(
            status[0], status[0].toUpperCase());
    }
  }

  Color get _statusColor {
    if (_isCancelled) return Colors.red;
    if (_isExpired) return Colors.grey;
    final status = _playdateData?['status'] ?? 'pending';
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return const Color(0xFF4CAF50);
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
    final title = _playdateData!['title'] ?? 'Walk Together';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        gradient: isLocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade100,
                  Colors.grey.shade50,
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF1F8E9),
                  Color(0xFFE8F5E9),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked
              ? Colors.grey.shade300
              : const Color(0xFF4CAF50).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isLocked ? Icons.lock_outline : Icons.pets,
                  size: 18,
                  color: _statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isLocked ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Walk details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location row
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16,
                        color:
                            isLocked ? Colors.grey : const Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isLocked ? Colors.grey[600] : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Time row
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 16,
                        color:
                            isLocked ? Colors.grey : const Color(0xFF4CAF50)),
                    const SizedBox(width: 6),
                    Text(
                      _formatDateTime(scheduledAt),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isLocked ? Colors.grey[600] : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Participants row
                if (_participants.isNotEmpty) ...[
                  Row(
                    children: [
                      // Participant avatars (stacked)
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
                            final dog = participant['dog']
                                as Map<String, dynamic>?;
                            final photoUrl =
                                dog?['main_photo_url'] as String?;

                            return Positioned(
                              left: idx * 22.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: photoUrl != null
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  backgroundColor: Colors.grey[200],
                                  child: photoUrl == null
                                      ? const Icon(Icons.pets, size: 14)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Text(
                        '${_participants.length} ${_participants.length == 1 ? 'participant' : 'participants'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: isLocked
                  ? OutlinedButton.icon(
                      onPressed: () => _viewDetails(context),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _viewDetails(context),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('View / Edit Walk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  Future<void> _viewDetails(BuildContext context) async {
    if (_playdateData == null) return;

    final parkName = _playdateData!['location'] as String? ?? 'Walk Location';
    final scheduledFor =
        DateTime.tryParse(_playdateData!['scheduled_at'] ?? '') ??
            DateTime.now();
    final organizer =
        _playdateData!['organizer'] as Map<String, dynamic>?;
    final organizerName = organizer?['name'] ?? 'Walk Organizer';

    await showWalkDetailsSheet(
      context,
      parkId: parkName,
      parkName: parkName,
      scheduledFor: scheduledFor,
      organizerDogName: organizerName,
      playdateId: widget.playdateId,
    );

    if (mounted) {
      _loadPlaydateData();
      widget.onUpdated?.call();
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

  Color get _statusColor {
    if (_isCancelled) return Colors.red;
    if (_isExpired) return Colors.grey;
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return const Color(0xFF4CAF50);
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get _statusText {
    if (_isCancelled) return 'Cancelled';
    if (_isExpired) return 'Completed';
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmed ✓';
      case 'pending':
        return 'Pending...';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(scheduledFor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isLocked
              ? Colors.grey.shade100
              : const Color(0xFF4CAF50).withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(
              color: _isLocked
                  ? Colors.grey.shade200
                  : const Color(0xFF4CAF50).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isLocked ? Icons.lock_outline : Icons.pets,
              size: 16,
              color: _statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$location • $timeStr',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isLocked ? Colors.grey[500] : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
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
