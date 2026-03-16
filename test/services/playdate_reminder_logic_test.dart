import 'package:flutter_test/flutter_test.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';

void main() {
  group('Playdate reminder timing', () {
    test('is due at trigger time', () {
      final scheduledAt = DateTime(2026, 3, 16, 12, 0);
      final now = DateTime(2026, 3, 16, 11, 0);

      final due = PlaydateRequestService.isReminderDue(
        now: now,
        scheduledAt: scheduledAt,
        minutesBefore: 60,
      );

      expect(due, isTrue);
    });

    test('is not due before trigger time', () {
      final scheduledAt = DateTime(2026, 3, 16, 12, 0);
      final now = DateTime(2026, 3, 16, 10, 59);

      final due = PlaydateRequestService.isReminderDue(
        now: now,
        scheduledAt: scheduledAt,
        minutesBefore: 60,
      );

      expect(due, isFalse);
    });

    test('is not due when already sent', () {
      final scheduledAt = DateTime(2026, 3, 16, 12, 0);
      final now = DateTime(2026, 3, 16, 11, 30);

      final due = PlaydateRequestService.isReminderDue(
        now: now,
        scheduledAt: scheduledAt,
        minutesBefore: 60,
        lastSentAt: DateTime(2026, 3, 16, 11, 0),
      );

      expect(due, isFalse);
    });

    test('supports 15-minute preset', () {
      final scheduledAt = DateTime(2026, 3, 16, 12, 0);
      final now = DateTime(2026, 3, 16, 11, 45);

      final due = PlaydateRequestService.isReminderDue(
        now: now,
        scheduledAt: scheduledAt,
        minutesBefore: 15,
      );

      expect(due, isTrue);
    });

    test('supports 1-day preset', () {
      final scheduledAt = DateTime(2026, 3, 17, 12, 0);
      final now = DateTime(2026, 3, 16, 12, 0);

      final due = PlaydateRequestService.isReminderDue(
        now: now,
        scheduledAt: scheduledAt,
        minutesBefore: 1440,
      );

      expect(due, isTrue);
    });
  });
}
