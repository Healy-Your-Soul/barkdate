import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/services/feature_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock FeatureFlags
class FakeFeatureFlags extends FeatureFlags {
  final bool slim;

  FakeFeatureFlags(this.slim);

  @override
  bool get useSlimBottomNav => slim;
}

void main() {
  setUpAll(() async {
    // Mock SharedPreferences for Supabase auth persistence
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase to prevent crashes in MainNavigation
    await Supabase.initialize(
      url: 'https://example.com',
      anonKey: 'dummy',
    );
  });

  testWidgets('MainNavigation shows 3 items when slimBottomNav is true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWithValue(FakeFeatureFlags(true)),
        ],
        child: const MaterialApp(
          home: MainNavigation(),
        ),
      ),
    );

    // Verify BottomNavigationBar has 3 items
    final botNav = find.byType(BottomNavigationBar);
    expect(botNav, findsOneWidget);

    final widget = tester.widget<BottomNavigationBar>(botNav);
    expect(widget.items.length, 3);

    expect(find.descendant(of: botNav, matching: find.text('Feed')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Map')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Profile')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Playdates')),
        findsNothing);
  });

  testWidgets('MainNavigation shows 6 items when slimBottomNav is false',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWithValue(FakeFeatureFlags(false)),
        ],
        child: const MaterialApp(
          home: MainNavigation(),
        ),
      ),
    );

    // Verify BottomNavigationBar has 6 items
    final botNav = find.byType(BottomNavigationBar);
    expect(botNav, findsOneWidget);

    final widget = tester.widget<BottomNavigationBar>(botNav);
    expect(widget.items.length, 6);

    expect(find.descendant(of: botNav, matching: find.text('Feed')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Map')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Playdates')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Events')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Messages')),
        findsOneWidget);
    expect(find.descendant(of: botNav, matching: find.text('Profile')),
        findsOneWidget);
  });
}
