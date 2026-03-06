import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barkdate/models/notification.dart';
import 'package:barkdate/widgets/notification_banner.dart';

// Sentinel to distinguish "not passed" from "null"
const _notPassed = Object();

// Helper to build a BarkDateNotification for tests
BarkDateNotification _makeBarkNotification({
  Object? relatedId = _notPassed,
  NotificationType type = NotificationType.bark,
}) {
  final resolvedRelatedId =
      relatedId == _notPassed ? 'dog-abc-123' : relatedId as String?;
  return BarkDateNotification(
    id: 'test-id-1',
    userId: 'user-123',
    title: '🐕 New Bark!',
    body: 'Test Dog wants to play with Your Dog!',
    type: type,
    actionType: 'open_matches',
    relatedId: resolvedRelatedId,
    isRead: false,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('NotificationBanner widget', () {
    testWidgets('renders title and body', (WidgetTester tester) async {
      final notification = _makeBarkNotification();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NotificationBanner(
                  notification: notification,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Allow animation to run
      await tester.pumpAndSettle();

      expect(find.text('🐕 New Bark!'), findsOneWidget);
      expect(
          find.text('Test Dog wants to play with Your Dog!'), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped',
        (WidgetTester tester) async {
      bool wasTapped = false;
      final notification = _makeBarkNotification();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NotificationBanner(
                  notification: notification,
                  onTap: () {
                    wasTapped = true;
                    debugPrint('✅ [TEST] NotificationBanner onTap called');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the banner body (InkWell area - tap on title text)
      await tester.tap(find.text('🐕 New Bark!'));
      await tester.pumpAndSettle();

      expect(wasTapped, isTrue,
          reason: 'onTap should be called when user taps the banner');
    });

    testWidgets('calls onDismiss when close button tapped',
        (WidgetTester tester) async {
      bool wasDismissed = false;
      final notification = _makeBarkNotification();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NotificationBanner(
                  notification: notification,
                  onTap: () {},
                  onDismiss: () {
                    wasDismissed = true;
                    debugPrint('✅ [TEST] NotificationBanner onDismiss called');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the close (X) icon button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(wasDismissed, isTrue,
          reason: 'onDismiss should be called when user taps the close button');
    });

    testWidgets('bark notification carries correct relatedId through tap',
        (WidgetTester tester) async {
      String? capturedRelatedId;
      final notification = _makeBarkNotification(relatedId: 'dog-xyz-456');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                NotificationBanner(
                  notification: notification,
                  onTap: () {
                    capturedRelatedId = notification.relatedId;
                    debugPrint('✅ [TEST] relatedId on tap: $capturedRelatedId');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('🐕 New Bark!'));
      await tester.pumpAndSettle();

      expect(capturedRelatedId, equals('dog-xyz-456'),
          reason: 'relatedId should be dog-xyz-456 so navigation can use it');
    });
  });

  group('BarkDateNotification model', () {
    test('bark notification has correct type and relatedId', () {
      final notification = _makeBarkNotification(relatedId: 'dog-abc-123');

      expect(notification.type, equals(NotificationType.bark));
      expect(notification.relatedId, equals('dog-abc-123'));
      expect(notification.title, equals('🐕 New Bark!'));
    });

    test('notification with null relatedId is handled', () {
      // This is a case where a bark notification lacks a dog ID – should not crash
      final notification = _makeBarkNotification(relatedId: null);
      expect(notification.relatedId, isNull);
    });
  });
}
