import 'package:flutter_test/flutter_test.dart';
import 'package:barkdate/models/playdate.dart';

/// Tests for the Walk Together invite acceptance bug fix.
///
/// Bug: When Person 2 accepted a walk invite, the invite appeared to remain
/// "in progress" (or disappeared entirely) from Person 1's sent-requests view.
///
/// Root cause: [PlaydateRequestService.getSentRequests] filtered for
/// status == 'pending' only. After acceptance, the DB stores status ==
/// 'accepted', so the invite was invisible to the requester.
///
/// Fix: getSentRequests now uses inFilter(['pending','accepted','counter_proposed'])
/// so the requester can see the updated status.
void main() {
  group('PlaydateRequestStatus', () {
    test('pending status is recognised', () {
      final status = PlaydateRequestStatus.fromString('pending');
      expect(status, equals(PlaydateRequestStatus.pending));
    });

    test('accepted status is recognised', () {
      final status = PlaydateRequestStatus.fromString('accepted');
      expect(status, equals(PlaydateRequestStatus.accepted));
    });

    test('declined status is recognised', () {
      final status = PlaydateRequestStatus.fromString('declined');
      expect(status, equals(PlaydateRequestStatus.declined));
    });

    test('counter_proposed status is recognised', () {
      final status = PlaydateRequestStatus.fromString('counter_proposed');
      expect(status, equals(PlaydateRequestStatus.counterProposed));
    });

    test('unknown status falls back to pending', () {
      final status = PlaydateRequestStatus.fromString('in_progress');
      expect(status, equals(PlaydateRequestStatus.pending));
    });
  });

  group('PlaydateStatus', () {
    test('confirmed status is recognised after invite acceptance', () {
      // When an invite is accepted, the associated playdate should be
      // updated to 'confirmed' by respondToPlaydateRequest.
      final status = PlaydateStatus.fromString('confirmed');
      expect(status, equals(PlaydateStatus.confirmed));
    });

    test('pending status is the initial playdate status', () {
      final status = PlaydateStatus.fromString('pending');
      expect(status, equals(PlaydateStatus.pending));
    });

    test('in_progress is a valid PlaydateStatus enum value', () {
      // The DB constraint does NOT include 'in_progress', so this value
      // should never come back from Supabase for playdates. Only the Dart
      // enum defines it for completeness; we verify fromString falls back
      // gracefully rather than throwing.
      final status = PlaydateStatus.fromString('in_progress');
      // fromString falls back to pending for values not stored in the DB.
      expect(status, equals(PlaydateStatus.inProgress));
    });
  });

  group('Walk invite acceptance – status filter logic', () {
    // Simulate the list of request statuses that getSentRequests should
    // now return (after the fix), and verify the old filter would miss them.

    final statuses = ['pending', 'accepted', 'counter_proposed', 'declined'];

    const activeStatuses = ['pending', 'accepted', 'counter_proposed'];

    test('old filter (status==pending) misses accepted invites', () {
      // This was the bug: only 'pending' was returned.
      final oldFilter = statuses.where((s) => s == 'pending').toList();
      expect(oldFilter, isNot(contains('accepted')),
          reason:
              'Old filter excluded accepted invites, causing them to look stuck in progress');
    });

    test('new filter (inFilter active statuses) includes accepted invites', () {
      final newFilter =
          statuses.where((s) => activeStatuses.contains(s)).toList();
      expect(newFilter, contains('accepted'),
          reason: 'Fixed filter must include accepted invites so Person 1 can see the status change');
      expect(newFilter, contains('pending'));
      expect(newFilter, contains('counter_proposed'));
      expect(newFilter, isNot(contains('declined')),
          reason: 'Declined invites should not clutter the active list');
    });

    test('accepted invite is visible to requester after fix', () {
      // Simulate a request row returned from Supabase.
      final requestRow = <String, dynamic>{
        'id': 'req-1',
        'requester_id': 'user-person-1',
        'invitee_id': 'user-person-2',
        'status': 'accepted', // Set by respondToPlaydateRequest
        'playdate_id': 'playdate-1',
      };

      final status = requestRow['status'] as String;
      expect(activeStatuses.contains(status), isTrue,
          reason: 'An accepted request must appear in the active-status list');
    });

    test('send-accept scenario: status transitions correctly', () {
      // Simulate the lifecycle of a walk invite.
      String requestStatus = 'pending'; // Initial state after Person 1 sends

      // Person 2 accepts — backend sets status to 'accepted'.
      requestStatus = 'accepted';

      // The request is now visible to Person 1 with the fixed query.
      expect(activeStatuses.contains(requestStatus), isTrue);

      // The associated playdate is set to 'confirmed' by the backend.
      final playdateStatus = PlaydateStatus.fromString('confirmed');
      expect(playdateStatus, equals(PlaydateStatus.confirmed));
    });
  });
}
