import 'package:flutter/material.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/design_system/app_spacing.dart';

/// Bottom sheet for scheduling a future walk at a park.
/// Pre-fills park info if opened from map selection.
class PlanWalkSheet extends StatefulWidget {
  final String parkId;
  final String parkName;
  final double? latitude;
  final double? longitude;

  const PlanWalkSheet({
    super.key,
    required this.parkId,
    required this.parkName,
    this.latitude,
    this.longitude,
  });

  @override
  State<PlanWalkSheet> createState() => _PlanWalkSheetState();
}

class _PlanWalkSheetState extends State<PlanWalkSheet> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to 1 hour from now
    final inOneHour = DateTime.now().add(const Duration(hours: 1));
    _selectedTime = TimeOfDay(hour: inOneHour.hour, minute: 0);
    _selectedDate = DateTime(inOneHour.year, inOneHour.month, inOneHour.day);
  }

  DateTime get _scheduledDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  Future<void> _scheduleWalk() async {
    if (_scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a time in the future')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await CheckInService.scheduleFutureCheckIn(
        parkId: widget.parkId,
        parkName: widget.parkName,
        scheduledFor: _scheduledDateTime,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

      if (!mounted) return;

      if (result != null) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🕐 Walk planned at ${widget.parkName}! Your pack will be notified.'),
            backgroundColor: const Color(0xFF0D47A1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to schedule walk')),
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

  @override
  Widget build(BuildContext context) {
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

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🕐', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan a Walk',
                      style: AppTypography.h3(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.parkName,
                      style: AppTypography.bodySmall(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Date picker
          Text('Date', style: AppTypography.labelMedium()),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(_selectedDate),
                    style: AppTypography.bodyMedium(),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Time picker
          Text('Time', style: AppTypography.labelMedium()),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (picked != null) {
                setState(() => _selectedTime = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 12),
                  Text(
                    _selectedTime.format(context),
                    style: AppTypography.bodyMedium(),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right,
                      color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your pack will see this walk and can join you!',
                    style: AppTypography.bodySmall(
                      color: const Color(0xFF0D47A1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Schedule button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _scheduleWalk,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Schedule Walk',
                      style: AppTypography.button(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == tomorrow) return 'Tomorrow';

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

/// Show the Plan Walk bottom sheet
void showPlanWalkSheet(
  BuildContext context, {
  required String parkId,
  required String parkName,
  double? latitude,
  double? longitude,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PlanWalkSheet(
      parkId: parkId,
      parkName: parkName,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}
