import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/services/notification_manager.dart';
import 'package:barkdate/services/reminder_dispatch_service.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/firebase_options.dart';
import 'package:barkdate/utils/maps_js_bridge.dart';
import 'package:barkdate/app.dart';
import 'package:barkdate/core/sentry/sentry_riverpod_observer.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:barkdate/services/feature_flags.dart';

/// A Completer that completes when the Google Maps API is ready.
final mapsApiReadyCompleter = Completer<void>();

Future<void> main() async {
  // Forward debugPrint to Sentry breadcrumbs/logs
  final oldDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      final lowerMessage = message.toLowerCase();

      // Always add as breadcrumb for error context (Quota-safe)
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        level: SentryLevel.info,
        category: 'debugPrint',
      ));

      // Only send to Logs tab if it's an Error/Warning OR we are in Release mode
      if (kReleaseMode ||
          lowerMessage.contains('error') ||
          lowerMessage.contains('warning') ||
          lowerMessage.contains('failed') ||
          lowerMessage.contains('exception') ||
          lowerMessage.contains('⚠️') ||
          lowerMessage.contains('❌')) {
        // Use error level if it sounds like an actual failure
        if (lowerMessage.contains('error') ||
            lowerMessage.contains('failed') ||
            lowerMessage.contains('exception')) {
          Sentry.logger.error(message);
        } else {
          Sentry.logger.info(message);
        }
      }
    }
    oldDebugPrint(message, wrapWidth: wrapWidth);
  };

  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.enableLogs = true;
      options.addIntegration(LoggingIntegration());
      options.sendDefaultPii = true;
      options.tracesSampleRate = 1.0;
      options.replay.sessionSampleRate = 0.1;
      options.replay.onErrorSampleRate = 1.0;
      options.attachScreenshot = true;
      options.environment = const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development';
    },
    appRunner: () async {
      if (kIsWeb) {
        registerMapsApiReadyCallback(() {
          if (!mapsApiReadyCompleter.isCompleted) {
            mapsApiReadyCompleter.complete();
          }
        });

        if (googleMapsApiLoadedFlag() && !mapsApiReadyCompleter.isCompleted) {
          mapsApiReadyCompleter.complete();
        }
      }

      WidgetsFlutterBinding.ensureInitialized();

      // Configure Google Fonts to NOT check asset manifest (fixes web debug mode)
      GoogleFonts.config.allowRuntimeFetching = true;

      // Initialize Firebase (for FCM, not auth)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Supabase (for everything else)
      await SupabaseConfig.initialize();

      // Initialize settings service
      await SettingsService().initialize();

      // Initialize comprehensive notification system
      await NotificationManager.initialize();

      // Start periodic reminder dispatching for due walk reminders.
      ReminderDispatchService().start();

      // Initialize Feature Flags
      await FeatureFlags.init();

      // Start cache cleanup (periodic cleanup every minute)
      CacheService().startPeriodicCleanup();

      // Capture a message to verify Sentry is working immediately
      Sentry.captureMessage('Sentry verified: BarkDate is reporting logs!');

      // Wrap app with Riverpod for map_v2 state management
      runApp(
        DefaultAssetBundle(
          bundle: SentryAssetBundle(),
          child: ProviderScope(
            observers: [SentryProviderObserver()],
            child: const BarkDateApp(),
          ),
        ),
      );
    },
  );
}
