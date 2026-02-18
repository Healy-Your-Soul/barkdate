import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/theme.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/playdate_action_popup.dart';
import 'package:barkdate/widgets/content_options_menu.dart';
import 'dart:async';

class DogCard extends StatefulWidget {
  final Dog dog;
  final VoidCallback onBarkPressed;
  final VoidCallback? onPlaydatePressed;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onTap;
  final bool isFriend; // Whether this dog is already in the user's pack
  final VoidCallback?
      onAddToPackPressed; // For non-friends: send bark/friend request

  const DogCard({
    super.key,
    required this.dog,
    required this.onBarkPressed,
    this.onPlaydatePressed,
    this.onOpenProfile,
    this.onTap,
    this.isFriend = true, // Default to true for backwards compatibility
    this.onAddToPackPressed,
  });

  @override
  State<DogCard> createState() => _DogCardState();
}

class _DogCardState extends State<DogCard> with SingleTickerProviderStateMixin {
  String _playdateStatus = 'none'; // 'none', 'pending', 'confirmed'
  Map<String, dynamic>?
      _currentPlaydate; // Store current playdate data when confirmed

  // Bark button animation
  late AnimationController _barkAnimationController;
  late Animation<double> _barkScaleAnimation;
  bool _hasBarked = false;
  Timer? _barkResetTimer;

  @override
  void initState() {
    super.initState();
    _checkPlaydateStatus();

    // Initialize bark animation
    _barkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _barkScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _barkAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _barkAnimationController.dispose();
    _barkResetTimer?.cancel();
    super.dispose();
  }

  void _handleBarkPressed() {
    // Trigger animation
    _barkAnimationController.forward(from: 0);

    // Set barked state
    setState(() => _hasBarked = true);

    // Call original callback
    widget.onBarkPressed();

    // Reset after 3 seconds
    _barkResetTimer?.cancel();
    _barkResetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _hasBarked = false);
      }
    });
  }

  Future<void> _checkPlaydateStatus() async {
    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      // Check for pending requests sent to this dog
      final pendingRequestsReceived = await SupabaseConfig.client
          .from('playdate_requests')
          .select('id, status')
          .eq('requester_id', user.id)
          .eq('invitee_id', widget.dog.ownerId)
          .eq('status', 'pending')
          .limit(1);

      if (pendingRequestsReceived.isNotEmpty) {
        setState(() => _playdateStatus = 'pending');
        return;
      }

      // Check for confirmed playdates with this specific dog's owner
      final confirmedAsOrganizer = await SupabaseConfig.client
          .from('playdates')
          .select(
              'id, organizer_id, participant_id, scheduled_at, title, description, location, status')
          .eq('organizer_id', user.id)
          .eq('participant_id', widget.dog.ownerId)
          .eq('status', 'confirmed')
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .limit(1);

      final confirmedAsParticipant = await SupabaseConfig.client
          .from('playdates')
          .select(
              'id, organizer_id, participant_id, scheduled_at, title, description, location, status')
          .eq('organizer_id', widget.dog.ownerId)
          .eq('participant_id', user.id)
          .eq('status', 'confirmed')
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .limit(1);

      if (confirmedAsOrganizer.isNotEmpty ||
          confirmedAsParticipant.isNotEmpty) {
        final playdateData = confirmedAsOrganizer.isNotEmpty
            ? confirmedAsOrganizer.first
            : confirmedAsParticipant.first;
        setState(() {
          _playdateStatus = 'confirmed';
          _currentPlaydate = playdateData;
        });
      }
    } catch (e) {
      debugPrint('Error checking playdate status: $e');
    }
  }

  void _showPlaydatePopup() {
    if (_currentPlaydate == null) return;

    showDialog(
      context: context,
      builder: (context) => PlaydateActionPopup(
        playdate: _currentPlaydate!,
        onCancel: () => Navigator.of(context).pop(),
        onReschedule: () {
          Navigator.of(context).pop();
          _showRescheduleDialog();
        },
      ),
    );
  }

  Future<void> _showRescheduleDialog() async {
    if (_currentPlaydate == null) return;

    final currentDate = DateTime.parse(_currentPlaydate!['scheduled_at']);
    DateTime selectedDate = currentDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(currentDate);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Playdate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Date: ${selectedDate.toString().split(' ')[0]}'),
              subtitle: const Text('Tap to change'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  selectedDate = picked;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text('Time: ${selectedTime.format(context)}'),
              subtitle: const Text('Tap to change'),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (picked != null) {
                  selectedTime = picked;
                  (context as Element).markNeedsBuild();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updatePlaydateTime(selectedDate, selectedTime);
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePlaydateTime(DateTime date, TimeOfDay time) async {
    try {
      final newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      await SupabaseConfig.client.from('playdates').update({
        'scheduled_at': newDateTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentPlaydate!['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playdate rescheduled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the playdate status
        _checkPlaydateStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Buttons for friends: Bark + Play
  Widget _buildFriendButtons(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bark button with animation and ink splash
        AnimatedBuilder(
          animation: _barkScaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _barkScaleAnimation.value,
            child: SizedBox(
              width: 80,
              height: 32,
              child: Material(
                color: const Color(0xFF4CAF50), // Always green
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _hasBarked ? null : _handleBarkPressed,
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.white.withOpacity(0.4),
                  highlightColor: Colors.white.withOpacity(0.2),
                  child: Center(
                    child: Text(
                      _hasBarked ? 'Barked!' : 'Bark',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Playdate button with state
        SizedBox(
          width: 80,
          height: 32,
          child: _playdateStatus == 'confirmed'
              ? OutlinedButton(
                  onPressed: _showPlaydatePopup,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 12, color: Colors.green),
                      const SizedBox(width: 2),
                      Text('EDIT',
                          style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green)),
                    ],
                  ),
                )
              : _playdateStatus == 'pending'
                  ? OutlinedButton(
                      onPressed: widget.onPlaydatePressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_empty,
                              size: 12, color: Colors.orange),
                          const SizedBox(width: 2),
                          Text('Sent',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange)),
                        ],
                      ),
                    )
                  : OutlinedButton(
                      onPressed: widget.onPlaydatePressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4CAF50),
                        side: const BorderSide(
                            color: Color(0xFF4CAF50), width: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 2),
                          Text('Play',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4CAF50))),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  /// Buttons for non-friends: Add to Pack + View Profile
  Widget _buildNonFriendButtons(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add to Pack button (sends friend request)
        SizedBox(
          width: 80,
          height: 32,
          child: ElevatedButton(
            onPressed: widget.onAddToPackPressed ?? widget.onBarkPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE89E5F), // Orange brand color
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Add to Pack',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // View Profile button
        SizedBox(
          width: 80,
          height: 32,
          child: OutlinedButton(
            onPressed: widget.onTap ?? widget.onOpenProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[400]!, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Profile',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dog = widget.dog;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Dog photo
              GestureDetector(
                onTap: widget.onOpenProfile,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: widget.dog.photos.isNotEmpty
                      ? Image.network(
                          widget.dog.photos.first,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.pets,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.pets,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Dog details
              Expanded(
                child: GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dog.breed}, ${dog.distanceKm.toStringAsFixed(1)} km away',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'with ${dog.ownerName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // Action buttons - conditional based on friendship status
              SizedBox(
                width: 85,
                child: widget.isFriend
                    ? _buildFriendButtons(theme)
                    : _buildNonFriendButtons(theme),
              ),
              // Subtle options menu (Report/Block)
              ContentOptionsMenu(
                contentType: 'dog_profile',
                contentId: dog.id ?? '',
                ownerId: dog.ownerId,
                ownerName: dog.ownerName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
