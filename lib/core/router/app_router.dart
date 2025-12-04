import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/features/profile/presentation/screens/dog_details_screen.dart';
import 'package:barkdate/models/dog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:barkdate/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:barkdate/features/feed/presentation/screens/feed_screen.dart';
import 'package:barkdate/features/map/presentation/screens/map_screen.dart';
import 'package:barkdate/features/events/presentation/screens/events_screen.dart';
import 'package:barkdate/features/playdates/presentation/screens/playdates_screen.dart';
import 'package:barkdate/features/playdates/presentation/screens/create_playdate_screen.dart';
import 'package:barkdate/features/messages/presentation/screens/messages_screen.dart';
import 'package:barkdate/features/messages/presentation/screens/chat_screen.dart';
import 'package:barkdate/features/events/presentation/screens/event_details_screen.dart';
import 'package:barkdate/features/playdates/presentation/screens/playdate_details_screen.dart';
import 'package:barkdate/features/profile/presentation/screens/profile_screen.dart';
import 'package:barkdate/features/settings/presentation/screens/settings_screen.dart';
import 'package:barkdate/features/social_feed/presentation/screens/social_feed_screen.dart';
import 'package:barkdate/features/gamification/presentation/screens/achievements_screen.dart';
import 'package:barkdate/features/premium/presentation/screens/premium_screen.dart';
import 'package:barkdate/core/presentation/widgets/scaffold_with_nav_bar.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/features/profile/presentation/screens/accept_share_screen.dart';
import 'package:barkdate/screens/admin_screen.dart';
import 'package:barkdate/screens/qr_checkin_screen.dart';
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SupabaseAuthWrapper(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'sign-up',
            builder: (context, state) => const SignUpScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/create-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateProfileScreen(
            userId: extra?['userId'],
            userName: extra?['userName'],
            userEmail: extra?['userEmail'],
            editMode: extra?['editMode'] ?? EditMode.createProfile,
          );
        },
      ),
      GoRoute(
        path: '/accept-share',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return AcceptShareScreen(initialCode: code);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const FeedFeatureScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (context, state) => const EventsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playdates',
                builder: (context, state) => const PlaydatesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (context, state) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'social-feed',
                    builder: (context, state) => const SocialFeedScreen(),
                  ),
                  GoRoute(
                    path: 'achievements',
                    builder: (context, state) => const AchievementsScreen(),
                  ),
                  GoRoute(
                    path: 'premium',
                    builder: (context, state) => const PremiumScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/dog-details',
        builder: (context, state) {
          final dog = state.extra as Dog;
          return DogDetailsScreen(dog: dog);
        },
      ),
      GoRoute(
        path: '/create-playdate',
        builder: (context, state) {
          final dog = state.extra as Dog?;
          return CreatePlaydateScreen(targetDog: dog);
        },
      ),
      GoRoute(
        path: '/event-details',
        builder: (context, state) {
          final event = state.extra as dynamic; // Can be Event object or Map
          return EventDetailsScreen(event: event);
        },
      ),
      GoRoute(
        path: '/playdate-details',
        builder: (context, state) {
          final playdate = state.extra as Map<String, dynamic>;
          return PlaydateDetailsScreen(playdate: playdate);
        },
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ChatScreen(
            matchId: extra['matchId'],
            recipientId: extra['recipientId'],
            recipientName: extra['recipientName'],
            recipientAvatarUrl: extra['recipientAvatarUrl'],
          );
        },
      ),
      // Admin route (unlisted - not in nav bar)
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      // QR Check-in route for deep links and web fallback
      GoRoute(
        path: '/checkin',
        builder: (context, state) {
          final parkId = state.uri.queryParameters['park'];
          final code = state.uri.queryParameters['code'];
          return QrCheckInScreen(parkId: parkId, code: code);
        },
      ),
    ],
  );
});
