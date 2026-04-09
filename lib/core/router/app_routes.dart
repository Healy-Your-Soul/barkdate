import 'package:flutter/material.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/screens/auth/forgot_password_screen.dart';
import 'package:barkdate/features/profile/presentation/screens/dog_details_screen.dart';
import 'package:barkdate/models/dog.dart';
import 'package:barkdate/models/event.dart';
import 'package:barkdate/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:barkdate/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:barkdate/features/feed/presentation/screens/feed_screen.dart';
import 'package:barkdate/screens/map_v2/map_tab_screen.dart';
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

import 'package:barkdate/core/presentation/widgets/scaffold_with_nav_bar.dart';
import 'package:barkdate/screens/onboarding/welcome_screen.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/widgets/supabase_auth_wrapper.dart';
import 'package:barkdate/features/profile/presentation/screens/accept_share_screen.dart';
import 'package:barkdate/screens/admin_screen.dart';
import 'package:barkdate/screens/qr_checkin_screen.dart';
import 'package:barkdate/screens/qr_scan_screen.dart';
import 'package:barkdate/screens/create_event_screen.dart';
import 'package:barkdate/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:barkdate/services/notification_manager.dart';
import 'package:go_router/go_router.dart';

part 'app_routes.g.dart';

@TypedGoRoute<SplashRoute>(path: '/')
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SupabaseAuthWrapper();
}

@TypedGoRoute<AuthRoute>(
  path: '/auth',
  routes: [
    TypedGoRoute<SignUpRoute>(path: 'sign-up'),
    TypedGoRoute<ForgotPasswordRoute>(path: 'forgot-password'),
  ],
)
class AuthRoute extends GoRouteData with $AuthRoute {
  const AuthRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignInScreen();
}

class ForgotPasswordRoute extends GoRouteData with $ForgotPasswordRoute {
  const ForgotPasswordRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ForgotPasswordScreen();
}

class SignUpRoute extends GoRouteData with $SignUpRoute {
  const SignUpRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SignUpScreen();
}

@TypedGoRoute<WelcomeRoute>(path: '/welcome')
class WelcomeRoute extends GoRouteData with $WelcomeRoute {
  const WelcomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const WelcomeScreen();
}

@TypedGoRoute<CreateProfileRoute>(path: '/create-profile')
class CreateProfileRoute extends GoRouteData with $CreateProfileRoute {
  final String? userId;
  final String? userName;
  final String? userEmail;
  final EditMode editMode;
  final String? dogId;

  const CreateProfileRoute({
    this.userId,
    this.userName,
    this.userEmail,
    this.editMode = EditMode.createProfile,
    this.dogId,
  });

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return CreateProfileScreen(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      editMode: editMode,
      dogId: dogId,
    );
  }
}

@TypedGoRoute<AcceptShareRoute>(path: '/accept-share')
class AcceptShareRoute extends GoRouteData with $AcceptShareRoute {
  final String? code;
  const AcceptShareRoute({this.code});
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AcceptShareScreen(initialCode: code);
}

@TypedStatefulShellRoute<AppShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<HomeBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<HomeRoute>(path: '/home'),
      ],
    ),
    TypedStatefulShellBranch<MapBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MapRoute>(path: '/map'),
      ],
    ),
    TypedStatefulShellBranch<PlaydatesBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<PlaydatesRoute>(path: '/playdates'),
      ],
    ),
    TypedStatefulShellBranch<EventsBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<EventsRoute>(path: '/events'),
      ],
    ),
    TypedStatefulShellBranch<MessagesBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<MessagesRoute>(path: '/messages'),
      ],
    ),
    TypedStatefulShellBranch<ProfileBranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ProfileRoute>(
          path: '/profile',
          routes: [
            TypedGoRoute<SettingsRoute>(path: 'settings'),
            TypedGoRoute<ProfileSocialFeedRoute>(path: 'social-feed'),
          ],
        ),
      ],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  const AppShellRouteData();
  @override
  Widget builder(BuildContext context, GoRouterState state,
      StatefulNavigationShell navigationShell) {
    NotificationManager.startNotificationStreams();
    return ScaffoldWithNavBar(navigationShell: navigationShell);
  }
}

class HomeBranchData extends StatefulShellBranchData {
  const HomeBranchData();
}

class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FeedFeatureScreen();
}

class MapBranchData extends StatefulShellBranchData {
  const MapBranchData();
}

class MapRoute extends GoRouteData with $MapRoute {
  const MapRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MapTabScreenV2();
}

class PlaydatesBranchData extends StatefulShellBranchData {
  const PlaydatesBranchData();
}

class PlaydatesRoute extends GoRouteData with $PlaydatesRoute {
  const PlaydatesRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PlaydatesScreen();
}

class EventsBranchData extends StatefulShellBranchData {
  const EventsBranchData();
}

class EventsRoute extends GoRouteData with $EventsRoute {
  const EventsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EventsScreen();
}

class MessagesBranchData extends StatefulShellBranchData {
  const MessagesBranchData();
}

class MessagesRoute extends GoRouteData with $MessagesRoute {
  const MessagesRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MessagesScreen();
}

class ProfileBranchData extends StatefulShellBranchData {
  const ProfileBranchData();
}

class ProfileRoute extends GoRouteData with $ProfileRoute {
  const ProfileRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileScreen();
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

class ProfileSocialFeedRoute extends GoRouteData with $ProfileSocialFeedRoute {
  const ProfileSocialFeedRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SocialFeedScreen();
}

@TypedGoRoute<AchievementsRoute>(path: '/achievements')
class AchievementsRoute extends GoRouteData with $AchievementsRoute {
  const AchievementsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AchievementsScreen();
}

@TypedGoRoute<DogDetailsByIdRoute>(path: '/dog/:id')
class DogDetailsByIdRoute extends GoRouteData with $DogDetailsByIdRoute {
  final String id;
  final Dog? $extra;

  const DogDetailsByIdRoute({required this.id, this.$extra});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if ($extra != null) {
      return DogDetailsScreen(dog: $extra!);
    }

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: SupabaseConfig.client
            .from('dogs')
            .select('*, users:user_id(*)')
            .eq('id', id)
            .single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Loading...')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            if (snapshot.hasError) {
              debugPrint(
                  'Error loading dog profile (ID: $id): ${snapshot.error}');
            }
            return Scaffold(
              appBar: AppBar(title: const Text('Dog Not Found')),
              body: const Center(
                child: Text(
                  'Error loading dog profile.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          try {
            final dogData = snapshot.data!;
            final fetchedDog = Dog.fromJson(dogData);
            return DogDetailsScreen(dog: fetchedDog);
          } catch (e) {
            debugPrint('Error parsing dog data (ID: $id): $e');
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('An unexpected error occurred.')),
            );
          }
        },
      ),
    );
  }
}

@TypedGoRoute<DogDetailsRoute>(path: '/dog-details')
class DogDetailsRoute extends GoRouteData with $DogDetailsRoute {
  final Dog $extra;
  const DogDetailsRoute({required this.$extra});
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DogDetailsScreen(dog: $extra);
}

@TypedGoRoute<CreatePlaydateRoute>(path: '/create-playdate')
class CreatePlaydateRoute extends GoRouteData with $CreatePlaydateRoute {
  final Dog? $extra;
  const CreatePlaydateRoute({this.$extra});
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CreatePlaydateScreen(targetDog: $extra);
}

@TypedGoRoute<CreateEventRoute>(path: '/create-event')
class CreateEventRoute extends GoRouteData with $CreateEventRoute {
  const CreateEventRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CreateEventScreen();
}

@TypedGoRoute<EventDetailsByIdRoute>(path: '/event/:id')
class EventDetailsByIdRoute extends GoRouteData with $EventDetailsByIdRoute {
  final String id;
  const EventDetailsByIdRoute({required this.id});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: SupabaseConfig.client
            .from('events')
            .select('*, users!organizer_id(name, avatar_url)')
            .eq('id', id)
            .single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading event'));
          }

          try {
            final eventData = snapshot.data!;
            final userData = eventData['users'] as Map<String, dynamic>?;
            final event = Event.fromJson({
              ...eventData,
              'organizer_name': userData?['name'] ?? 'Unknown',
              'organizer_avatar_url': userData?['avatar_url'] ?? '',
            });
            return EventDetailsScreen(event: event);
          } catch (e) {
            return Center(child: Text('Error parsing event: $e'));
          }
        },
      ),
    );
  }
}

@TypedGoRoute<EventDetailsRoute>(path: '/event-details')
class EventDetailsRoute extends GoRouteData with $EventDetailsRoute {
  final dynamic $extra;
  const EventDetailsRoute({this.$extra});
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      EventDetailsScreen(event: $extra);
}

@TypedGoRoute<PlaydateDetailsRoute>(path: '/playdate-details')
class PlaydateDetailsRoute extends GoRouteData with $PlaydateDetailsRoute {
  final Map<String, dynamic> $extra;
  const PlaydateDetailsRoute({required this.$extra});
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PlaydateDetailsScreen(playdate: $extra);
}

@TypedGoRoute<ChatRoute>(path: '/chat')
class ChatRoute extends GoRouteData with $ChatRoute {
  final String matchId;
  final String recipientId;
  final String recipientName;
  final String recipientAvatarUrl;

  const ChatRoute({
    required this.matchId,
    required this.recipientId,
    required this.recipientName,
    required this.recipientAvatarUrl,
  });

  @override
  Widget build(BuildContext context, GoRouterState state) => ChatScreen(
        matchId: matchId,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientAvatarUrl: recipientAvatarUrl,
      );
}

@TypedGoRoute<SocialFeedRoute>(path: '/social-feed')
class SocialFeedRoute extends GoRouteData with $SocialFeedRoute {
  final int initialTab;
  final bool openCreatePost;

  const SocialFeedRoute({
    this.initialTab = 0,
    this.openCreatePost = false,
  });

  @override
  Widget build(BuildContext context, GoRouterState state) => SocialFeedScreen(
        initialTab: initialTab,
        openCreatePost: openCreatePost,
      );
}

@TypedGoRoute<NotificationsRoute>(path: '/notifications')
class NotificationsRoute extends GoRouteData with $NotificationsRoute {
  const NotificationsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationsScreen();
}

@TypedGoRoute<AdminRoute>(path: '/admin')
class AdminRoute extends GoRouteData with $AdminRoute {
  const AdminRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AdminScreen();
}

@TypedGoRoute<QrScanRoute>(path: '/qr-scan')
class QrScanRoute extends GoRouteData with $QrScanRoute {
  const QrScanRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const QrScanScreen();
}

@TypedGoRoute<QrCheckinRoute>(path: '/checkin')
class QrCheckinRoute extends GoRouteData with $QrCheckinRoute {
  final String? park;
  final String? code;

  const QrCheckinRoute({this.park, this.code});

  @override
  Widget build(BuildContext context, GoRouterState state) => QrCheckInScreen(
        parkId: park,
        code: code,
      );
}
