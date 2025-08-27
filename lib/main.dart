import 'package:flutter/material.dart';
import 'package:barkdate/theme.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/auth/sign_in_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/photo_upload_service.dart';
import 'package:barkdate/screens/onboarding/location_permission_screen.dart';
import 'package:barkdate/screens/auth/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Initialize Storage buckets for photos 📸
  // Temporarily disabled - will create buckets after successful signup
  // await PhotoUploadService.ensureBucketsExist();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarkDate',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthChecker(), // Check if user is already logged in
    );
  }
}

/// Simple widget to check if user is already authenticated
class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseConfig.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check if user is already signed in
        final user = SupabaseConfig.auth.currentUser;
        
        if (user != null) {
          final isVerified = user.emailConfirmedAt != null;
          if (!isVerified) {
            return VerifyEmailScreen(email: user.email ?? '');
          }

          // User is logged in and verified; check if profile exists
          return FutureBuilder(
            future: _checkUserProfile(user.id),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final hasProfile = profileSnapshot.data ?? false;
              if (hasProfile) {
                return const MainNavigation();
              } else {
                // User needs to complete profile setup - go directly to profile creation
                return CreateProfileScreen(
                  userName: user.userMetadata?['name'] ?? '',
                  userEmail: user.email ?? '',
                  userId: user.id,
                );
              }
            },
          );
        } else {
          // No user, show welcome/sign in
          return const WelcomeScreen();
        }
      },
    );
  }

  Future<bool> _checkUserProfile(String userId) async {
    try {
      final profile = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );
      return profile != null;
    } catch (e) {
      return false;
    }
  }
}
