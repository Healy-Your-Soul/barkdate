import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/screens/auth_screen.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';

enum ProfileStatus {
  complete,
  needsDogProfile,
  needsFullSetup,
}

class SupabaseAuthWrapper extends StatefulWidget {
  const SupabaseAuthWrapper({super.key});

  @override
  State<SupabaseAuthWrapper> createState() => _SupabaseAuthWrapperState();
}

class _SupabaseAuthWrapperState extends State<SupabaseAuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = snapshot.data?.session;
        
        if (session != null) {
          // User is signed in, check if they need onboarding
          return FutureBuilder<ProfileStatus>(
            future: _checkUserProfileComplete(session.user.id),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              switch (profileSnapshot.data) {
                case ProfileStatus.complete:
                  // Profile complete, go to main app
                  return const MainNavigation();
                
                case ProfileStatus.needsDogProfile:
                  // User exists but needs dog profile
                  return CreateProfileScreen(
                    userId: session.user.id,
                    userName: session.user.userMetadata?['full_name'] ?? session.user.email?.split('@')[0],
                    userEmail: session.user.email,
                    editMode: EditMode.createProfile,
                  );
                
                case ProfileStatus.needsFullSetup:
                default:
                  // Needs full setup, show welcome then onboarding
                  return const WelcomeScreen();
              }
            },
          );
        } else {
          // User not signed in, show auth screen
          return const AuthScreen();
        }
      },
    );
  }

  Future<ProfileStatus> _checkUserProfileComplete(String userId) async {
    try {
      // Check if user has profile in Supabase
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('id, name, bio, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      // If no user profile exists at all, need full onboarding
      if (userResponse == null) {
        return ProfileStatus.needsFullSetup;
      }

      // Check if basic user info is complete
      final hasUserName = userResponse['name'] != null && userResponse['name'].toString().isNotEmpty;
      
      if (!hasUserName) {
        return ProfileStatus.needsFullSetup;
      }

      // Check if user has at least one dog
      final dogsResponse = await Supabase.instance.client
          .from('dogs')
          .select('id, name')
          .eq('user_id', userId)
          .limit(1);

      final hasDog = dogsResponse.isNotEmpty;

      if (hasDog) {
        return ProfileStatus.complete;
      } else {
        return ProfileStatus.needsDogProfile;
      }
      
    } catch (e) {
      print('Error checking user profile: $e');
      return ProfileStatus.needsFullSetup;
    }
  }
}
