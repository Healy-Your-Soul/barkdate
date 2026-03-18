import 'package:barkdate/app.dart';
import 'package:barkdate/main.dart' as app;
import 'package:barkdate/services/firebase_messaging_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String testPassword = String.fromEnvironment('TEST_PASSWORD');

  // Emails to ensure exist for the testing suite
  final testEmails = ['test_user1@example.com', 'test_user2@example.com'];

  group('end-to-end test', () {
    testWidgets('verify app launches', (tester) async {
      // Skip notification permission prompt to avoid blocking the test with modal dialogs
      FirebaseMessagingService.skipPermissionRequest = true;

      // Start the app which initializes all services (Firebase, Supabase, Riverpod, etc.)
      await app.main();

      // Wait for the app to load. Using pump avoids getting stuck on Spinners
      await tester.pump(const Duration(seconds: 2));

      // Verify the widget tree is built and running.
      expect(find.byType(BarkDateApp), findsOneWidget);

      // --- AUTH FLOW EXTENSION ---

      // 1. Force Log Out if already logged in to ensure deterministic test from SignIn screen
      if (SupabaseConfig.auth.currentUser != null) {
        await SupabaseConfig.auth.signOut();
        // Wait for redirect to auth/welcome screen
        await tester.pumpAndSettle();
      }

      // Allow redirect to settle on Sign In Screen
      await tester.pump(const Duration(seconds: 1));

      // 2. Enter Credentials using explicit keys added to the widgets
      await tester.enterText(
          find.byKey(const Key('email_field')), testEmails[0]);
      await tester.enterText(
          find.byKey(const Key('password_field')), testPassword);

      // 3. Tap the button
      // Ensure the button is visible (not obscured by keyboard or off-screen in scroll view)
      await tester.ensureVisible(find.byKey(const Key('sign_in_button')));
      await tester.tap(find.byKey(const Key('sign_in_button')));

      // Wait until home screen content loads
      await waitForWidget(tester, find.text('Bark'));

      // 4. Verify login succeeded by finding a home screen element (e.g., Feed navbar label)
      expect(find.text('Bark'), findsOneWidget);
    });
  });
}

/// Helper function to wait for a widget to appear in the tree (typical for async delays)
Future<void> waitForWidget(WidgetTester tester, Finder finder,
    {int timeoutSeconds = 15}) async {
  int attempts = 0;
  while (attempts < timeoutSeconds) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(seconds: 1));
    attempts++;
  }
  throw Exception('Timed out waiting for widget matching: $finder');
}
