import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:barkdate/design_system/app_theme.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/auth_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/services/notification_manager.dart';
import 'package:barkdate/services/cache_service.dart';
import 'package:barkdate/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService(),
      builder: (context, child) {
        return MaterialApp(
          title: 'BarkDate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: SettingsService().themeMode, // Use settings service theme
          home: const SupabaseAuthWrapper(), // Use Supabase Auth only
          routes: {
            '/auth': (context) => const AuthScreen(),
            '/home': (context) => const MainNavigation(),
            '/welcome': (context) => const WelcomeScreen(),
          },
        );
      },
    );
  }
}
