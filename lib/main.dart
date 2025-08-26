import 'package:flutter/material.dart';
import 'package:barkdate/theme.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/auth/sign_in_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/photo_upload_service.dart';

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
          // User is logged in, go to main app! 🎉
          return const MainNavigation();
        } else {
          // No user, show welcome/sign in
          return const WelcomeScreen();
          // For development, you can change this to:
          // return const SignInScreen(); // Skip welcome and go to sign in
        }
      },
    );
  }
}
