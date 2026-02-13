import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/auth/presentation/screens/sign_in_screen.dart';
// import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/services/preload_service.dart';
import 'package:barkdate/widgets/dog_loading_widget.dart';

enum ProfileStatus {
  complete,
  needsDogProfile,
  needsFullSetup,
}

class SupabaseAuthWrapper extends StatefulWidget {
  const SupabaseAuthWrapper({super.key});

  @override
  State<SupabaseAuthWrapper> createState() => _SupabaseAuthWrapperState();

  /// Clear profile cache (call when user signs out or updates profile)
  static void clearProfileCache(String userId) {
    _SupabaseAuthWrapperState.clearProfileCache(userId);
  }
}

class _SupabaseAuthWrapperState extends State<SupabaseAuthWrapper> {
  // Cache profile status to avoid redundant database queries on app refresh
  static final Map<String, ProfileStatus> _profileStatusCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const _cacheExpiry = Duration(minutes: 15);

  /// Clear profile cache (call when user signs out or updates profile)
  static void clearProfileCache(String userId) {
    _profileStatusCache.remove('profile_status_$userId');
    _cacheTimestamps.remove('profile_status_$userId');
    debugPrint('🗑️ Cleared profile status cache for $userId');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: DogLoadingWidget(
                size: 150,
                message: 'Connecting...',
              ),
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
                    child: DogLoadingWidget(
                      size: 150,
                      message: 'Getting your profile...',
                    ),
                  ),
                );
              }

              switch (profileSnapshot.data) {
                case ProfileStatus.complete:
                  // Profile complete, warm caches first then show app
                  debugPrint('🚀 Profile complete - warming caches for ${session.user.id}');
                  return FutureBuilder<void>(
                    future: PreloadService.warmFeedCaches(session.user.id),
                    builder: (context, cacheSnapshot) {
                      if (cacheSnapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(
                            child: DogLoadingWidget(
                              size: 150,
                              message: 'Loading your feed...',
                            ),
                          ),
                        );
                      }
                      debugPrint('✅ Cache warming completed - redirecting to /home');
                      // Use addPostFrameCallback to avoid navigation during build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          context.go('/home');
                        }
                      });
                      return const Scaffold(
                        body: Center(
                          child: DogLoadingWidget(
                            size: 150,
                            message: 'Almost there...',
                          ),
                        ),
                      );
                    },
                  );
                
                case ProfileStatus.needsDogProfile:
                  // User exists but needs dog profile
                  // Show onboarding screens first for new users (Google sign-in skips to here)
                  // WelcomeScreen will then navigate to CreateProfileScreen
                  return const WelcomeScreen();
                
                case ProfileStatus.needsFullSetup:
                default:
                  // Needs full setup, show welcome then onboarding
                  return const WelcomeScreen();
              }
            },
          );
        } else {
          // User not signed in, show auth screen
          return const SignInScreen();
        }
      },
    );
  }

  Future<ProfileStatus> _checkUserProfileComplete(String userId) async {
    // Check cache first for instant app refresh
    final cacheKey = 'profile_status_$userId';
    final cachedStatus = _profileStatusCache[cacheKey];
    final cacheTime = _cacheTimestamps[cacheKey];
    
    if (cachedStatus != null && cacheTime != null) {
      final age = DateTime.now().difference(cacheTime);
      if (age <= _cacheExpiry) {
        debugPrint('✓ Returning CACHED profile status for $userId (age: ${age.inSeconds}s)');
        
        // Verify in background (don't block UI)
        _verifyProfileStatusInBackground(userId);
        
        return cachedStatus;
      } else {
        debugPrint('⚠️ Profile status cache expired for $userId (age: ${age.inSeconds}s)');
      }
    }

    // No cache or expired - fetch fresh
    debugPrint('Fetching FRESH profile status for $userId');
    final status = await _fetchProfileStatus(userId);
    
    // Cache the result
    _profileStatusCache[cacheKey] = status;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    return status;
  }

  Future<ProfileStatus> _fetchProfileStatus(String userId) async {
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
      debugPrint('Error checking user profile: $e');
      return ProfileStatus.needsFullSetup;
    }
  }

  void _verifyProfileStatusInBackground(String userId) {
    // Verify in background without blocking UI
    _fetchProfileStatus(userId).then((freshStatus) {
      final cacheKey = 'profile_status_$userId';
      final cachedStatus = _profileStatusCache[cacheKey];
      
      if (freshStatus != cachedStatus) {
        // Status changed! Update cache and possibly navigate
        debugPrint('⚠️ Profile status changed from $cachedStatus to $freshStatus');
        _profileStatusCache[cacheKey] = freshStatus;
        _cacheTimestamps[cacheKey] = DateTime.now();
        
        // If user needs onboarding now, trigger rebuild to show correct screen
        if (mounted && freshStatus != ProfileStatus.complete) {
          setState(() {});
        }
      }
    }).catchError((e) {
      debugPrint('Background profile verification failed: $e');
    });
  }
}
