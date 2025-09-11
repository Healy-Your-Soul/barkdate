import 'package:flutter/material.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/theme.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/widgets/playdate_action_popup.dart';
import 'dart:async';

class DogCard extends StatefulWidget {
  final Dog dog;
  final VoidCallback onBarkPressed;
  final VoidCallback? onPlaydatePressed;
  final VoidCallback? onOpenProfile;

  const DogCard({
    super.key,
    required this.dog,
    required this.onBarkPressed,
    this.onPlaydatePressed,
    this.onOpenProfile,
  });

  @override
  State<DogCard> createState() => _DogCardState();
}

class _DogCardState extends State<DogCard> {
  String _playdateStatus = 'none'; // 'none', 'pending', 'confirmed'
  Map<String, dynamic>? _currentPlaydate; // Store current playdate data when confirmed
  
  @override
  void initState() {
    super.initState();
    _checkPlaydateStatus();
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
          .select('id, organizer_id, participant_id, scheduled_at, title, description, location, status')
          .eq('organizer_id', user.id)
          .eq('participant_id', widget.dog.ownerId)
          .eq('status', 'confirmed')
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .limit(1);

      final confirmedAsParticipant = await SupabaseConfig.client
          .from('playdates')
          .select('id, organizer_id, participant_id, scheduled_at, title, description, location, status')
          .eq('organizer_id', widget.dog.ownerId)
          .eq('participant_id', user.id)
          .eq('status', 'confirmed')
          .gte('scheduled_at', DateTime.now().toIso8601String())
          .limit(1);

      if (confirmedAsOrganizer.isNotEmpty || confirmedAsParticipant.isNotEmpty) {
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

      await SupabaseConfig.client
          .from('playdates')
          .update({
        'scheduled_at': newDateTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', _currentPlaydate!['id']);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dog = widget.dog;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Dog photo
            GestureDetector(
              onTap: widget.onOpenProfile,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.network(
                  widget.dog.photos.first,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
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
                      '${dog.breed}, ${dog.distanceKm.toStringAsFixed(1)} miles',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'with ${dog.ownerName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Action buttons (Bark and Playdate)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bark button
                SizedBox(
                  width: 85,
                  child: ElevatedButton(
                    onPressed: widget.onBarkPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark 
                        ? DarkModeColors.darkBarkButton 
                        : LightModeColors.lightBarkButton,
                      foregroundColor: isDark 
                        ? DarkModeColors.darkOnBarkButton 
                        : LightModeColors.lightOnBarkButton,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Bark',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark 
                          ? DarkModeColors.darkOnBarkButton 
                          : LightModeColors.lightOnBarkButton,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Playdate button with state
                SizedBox(
                  width: 85,
                  child: _playdateStatus == 'confirmed'
                      ? OutlinedButton.icon(
                          onPressed: _showPlaydatePopup,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(
                              color: Colors.green,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          label: Text(
                            'EDIT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        )
                      : _playdateStatus == 'pending'
                          ? OutlinedButton.icon(
                              onPressed: widget.onPlaydatePressed,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(
                                  color: Colors.orange,
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(
                                Icons.hourglass_empty,
                                size: 14,
                                color: Colors.orange,
                              ),
                              label: Text(
                                'Sent',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: widget.onPlaydatePressed,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              label: Text(
                                'Play',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}