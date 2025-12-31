import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/services/notification_manager.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/firebase_options.dart';
import 'package:barkdate/utils/maps_js_bridge.dart';
import 'package:barkdate/app.dart';

/// A Completer that completes when the Google Maps API is ready.
final mapsApiReadyCompleter = Completer<void>();

void main() async {
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
  // This forces Google Fonts to always fetch from HTTP instead of looking for bundled assets
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
  
  // Start cache cleanup (periodic cleanup every minute)
  CacheService().startPeriodicCleanup();
  
  // Wrap app with Riverpod for map_v2 state management
  runApp(const ProviderScope(child: BarkDateApp()));
}
