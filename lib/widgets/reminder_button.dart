import 'package:flutter/material.dart';
import 'package:barkdate/services/calendar_integration_service.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Compact "Remind me" button for confirmed walk surfaces (chat walk card,
/// walk details sheet). Shows the current reminder state at a glance and,
/// on tap, opens a small picker to set / change / cancel the reminder.
///
/// Idempotent — re-tapping the button updates the preference; the
/// "Cancel reminder" option in the picker flips `enabled=false` rather
/// than deleting the row (the dispatcher's predicate already gates on
/// `enabled = true`).
///
/// Surface contract: the parent decides whether to render this widget.
/// Hide it for past walks (no point in reminding) and locked / cancelled
/// walks. The button itself just trusts the data it's given.
class ReminderButton extends StatefulWidget {
  final String playdateId;
  final String? playdateRequestId;
  final DateTime scheduledAt;
  final String walkTitle;
  final String walkLocation;

  /// Optional override for the button's compact display style. The default
  /// (`compact: true`) renders a small OutlinedButton.icon designed to sit
  /// next to other action buttons in a row. Set `false` for full-width.
  final bool compact;

  const ReminderButton({
    super.key,
    required this.playdateId,
    required this.scheduledAt,
    required this.walkTitle,
    required this.walkLocation,
    this.playdateRequestId,
    this.compact = true,
  });

  @override
  State<ReminderButton> createState() => _ReminderButtonState();
}

class _ReminderButtonState extends State<ReminderButton> {
  /// Current minutes_before, or null if no reminder set / disabled.
  int? _currentMinutes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final pref = await PlaydateRequestService.getReminderPreferenceForPlaydate(
      userId: uid,
      playdateId: widget.playdateId,
    );
    if (!mounted) return;
    setState(() {
      _currentMinutes = (pref != null && pref['enabled'] == true)
          ? (pref['minutes_before'] as num?)?.toInt()
          : null;
      _loading = false;
    });
  }

  Future<void> _openPicker() async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => _ReminderPicker(initialMinutes: _currentMinutes),
    );
    if (result == null) return;

    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) return;

    switch (result.kind) {
      case _PickerResultKind.calendar:
        await CalendarIntegrationService.addPlaydateToCalendar(
          title: widget.walkTitle,
          startTime: widget.scheduledAt,
          endTime: widget.scheduledAt.add(const Duration(minutes: 60)),
          location: widget.walkLocation,
          description: 'Planned with BarkDate',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening calendar…')),
        );
        return;

      case _PickerResultKind.cancel:
        await PlaydateRequestService.upsertReminderPreference(
          userId: uid,
          playdateId: widget.playdateId,
          requestId: widget.playdateRequestId ?? '',
          minutesBefore: _currentMinutes ?? 60,
          enabled: false,
        );
        if (!mounted) return;
        setState(() => _currentMinutes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder cancelled.')),
        );
        return;

      case _PickerResultKind.save:
        final mins = result.minutes!;
        final ok = await PlaydateRequestService.upsertReminderPreference(
          userId: uid,
          playdateId: widget.playdateId,
          requestId: widget.playdateRequestId ?? '',
          minutesBefore: mins,
          enabled: true,
        );
        if (!mounted) return;
        if (ok) {
          setState(() => _currentMinutes = mins);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder set ${_humanLabel(mins)} before.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save reminder. Try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
    }
  }

  static String _humanLabel(int minutes) {
    switch (minutes) {
      case 15:
        return '15 min';
      case 60:
        return '1 hour';
      case 1440:
        return '1 day';
      default:
        return '$minutes min';
    }
  }

  String get _label {
    if (_currentMinutes == null) return 'Remind me';
    return 'Reminder: ${_humanLabel(_currentMinutes!)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.compact ? 130 : double.infinity,
        height: 40,
        child: const Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isSet = _currentMinutes != null;
    final fg = isSet ? Colors.green.shade700 : Colors.grey.shade700;
    final border = isSet ? Colors.green.shade300 : Colors.grey.shade300;

    final button = OutlinedButton.icon(
      onPressed: _openPicker,
      icon: Icon(
        isSet ? Icons.notifications_active : Icons.notifications_none,
        size: 18,
      ),
      label: Text(_label),
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    if (widget.compact) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

// ── Picker bottom sheet ──────────────────────────────────────────────────────

enum _PickerResultKind { save, cancel, calendar }

class _PickerResult {
  final _PickerResultKind kind;
  final int? minutes; // only for save
  const _PickerResult.save(this.minutes) : kind = _PickerResultKind.save;
  const _PickerResult.cancel()
      : kind = _PickerResultKind.cancel,
        minutes = null;
  const _PickerResult.calendar()
      : kind = _PickerResultKind.calendar,
        minutes = null;
}

class _ReminderPicker extends StatefulWidget {
  final int? initialMinutes;
  const _ReminderPicker({this.initialMinutes});

  @override
  State<_ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<_ReminderPicker> {
  late int? _selected = widget.initialMinutes;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int minutes) => ChoiceChip(
          label: Text(label),
          selected: _selected == minutes,
          onSelected: (_) => setState(() => _selected = minutes),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Remind me before the walk',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                chip('15 min', 15),
                chip('1 hour', 60),
                chip('1 day', 1440),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, const _PickerResult.calendar()),
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Add to calendar instead'),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.initialMinutes != null)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () =>
                      Navigator.pop(context, const _PickerResult.cancel()),
                  child: const Text('Cancel reminder'),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          _PickerResult.save(_selected),
                        ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
