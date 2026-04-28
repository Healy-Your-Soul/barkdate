// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $splashRoute,
      $authRoute,
      $welcomeRoute,
      $fastTrackOnboardingRoute,
      $createProfileRoute,
      $acceptShareRoute,
      $appShellRouteData,
      $achievementsRoute,
      $dogDetailsByIdRoute,
      $dogDetailsRoute,
      $createPlaydateRoute,
      $createEventRoute,
      $eventDetailsByIdRoute,
      $eventDetailsRoute,
      $playdateDetailsRoute,
      $chatRoute,
      $socialFeedRoute,
      $notificationsRoute,
      $adminRoute,
      $qrScanRoute,
      $qrCheckinRoute,
    ];

RouteBase get $splashRoute => GoRouteData.$route(
      path: '/',
      factory: $SplashRoute._fromState,
    );

mixin $SplashRoute on GoRouteData {
  static SplashRoute _fromState(GoRouterState state) => const SplashRoute();

  @override
  String get location => GoRouteData.$location(
        '/',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $authRoute => GoRouteData.$route(
      path: '/auth',
      factory: $AuthRoute._fromState,
      routes: [
        GoRouteData.$route(
          path: 'sign-up',
          factory: $SignUpRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'forgot-password',
          factory: $ForgotPasswordRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'verify-email',
          factory: $VerifyEmailRoute._fromState,
        ),
      ],
    );

mixin $AuthRoute on GoRouteData {
  static AuthRoute _fromState(GoRouterState state) => const AuthRoute();

  @override
  String get location => GoRouteData.$location(
        '/auth',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SignUpRoute on GoRouteData {
  static SignUpRoute _fromState(GoRouterState state) => const SignUpRoute();

  @override
  String get location => GoRouteData.$location(
        '/auth/sign-up',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ForgotPasswordRoute on GoRouteData {
  static ForgotPasswordRoute _fromState(GoRouterState state) =>
      const ForgotPasswordRoute();

  @override
  String get location => GoRouteData.$location(
        '/auth/forgot-password',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $VerifyEmailRoute on GoRouteData {
  static VerifyEmailRoute _fromState(GoRouterState state) => VerifyEmailRoute(
        email: state.uri.queryParameters['email']!,
      );

  VerifyEmailRoute get _self => this as VerifyEmailRoute;

  @override
  String get location => GoRouteData.$location(
        '/auth/verify-email',
        queryParams: {
          'email': _self.email,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $welcomeRoute => GoRouteData.$route(
      path: '/welcome',
      factory: $WelcomeRoute._fromState,
    );

mixin $WelcomeRoute on GoRouteData {
  static WelcomeRoute _fromState(GoRouterState state) => const WelcomeRoute();

  @override
  String get location => GoRouteData.$location(
        '/welcome',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $fastTrackOnboardingRoute => GoRouteData.$route(
      path: '/fast-track-onboarding',
      factory: $FastTrackOnboardingRoute._fromState,
    );

mixin $FastTrackOnboardingRoute on GoRouteData {
  static FastTrackOnboardingRoute _fromState(GoRouterState state) =>
      FastTrackOnboardingRoute(
        userId: state.uri.queryParameters['user-id'],
        userName: state.uri.queryParameters['user-name'],
      );

  FastTrackOnboardingRoute get _self => this as FastTrackOnboardingRoute;

  @override
  String get location => GoRouteData.$location(
        '/fast-track-onboarding',
        queryParams: {
          if (_self.userId != null) 'user-id': _self.userId,
          if (_self.userName != null) 'user-name': _self.userName,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $createProfileRoute => GoRouteData.$route(
      path: '/create-profile',
      factory: $CreateProfileRoute._fromState,
    );

mixin $CreateProfileRoute on GoRouteData {
  static CreateProfileRoute _fromState(GoRouterState state) =>
      CreateProfileRoute(
        userId: state.uri.queryParameters['user-id'],
        userName: state.uri.queryParameters['user-name'],
        userEmail: state.uri.queryParameters['user-email'],
        editMode: _$convertMapValue('edit-mode', state.uri.queryParameters,
                _$EditModeEnumMap._$fromName) ??
            EditMode.createProfile,
        dogId: state.uri.queryParameters['dog-id'],
      );

  CreateProfileRoute get _self => this as CreateProfileRoute;

  @override
  String get location => GoRouteData.$location(
        '/create-profile',
        queryParams: {
          if (_self.userId != null) 'user-id': _self.userId,
          if (_self.userName != null) 'user-name': _self.userName,
          if (_self.userEmail != null) 'user-email': _self.userEmail,
          if (_self.editMode != EditMode.createProfile)
            'edit-mode': _$EditModeEnumMap[_self.editMode],
          if (_self.dogId != null) 'dog-id': _self.dogId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

const _$EditModeEnumMap = {
  EditMode.createProfile: 'create-profile',
  EditMode.editDog: 'edit-dog',
  EditMode.editOwner: 'edit-owner',
  EditMode.editBoth: 'edit-both',
  EditMode.addNewDog: 'add-new-dog',
};

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

extension<T extends Enum> on Map<T, String> {
  T? _$fromName(String? value) =>
      entries.where((element) => element.value == value).firstOrNull?.key;
}

RouteBase get $acceptShareRoute => GoRouteData.$route(
      path: '/accept-share',
      factory: $AcceptShareRoute._fromState,
    );

mixin $AcceptShareRoute on GoRouteData {
  static AcceptShareRoute _fromState(GoRouterState state) => AcceptShareRoute(
        code: state.uri.queryParameters['code'],
      );

  AcceptShareRoute get _self => this as AcceptShareRoute;

  @override
  String get location => GoRouteData.$location(
        '/accept-share',
        queryParams: {
          if (_self.code != null) 'code': _self.code,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
      factory: $AppShellRouteDataExtension._fromState,
      branches: [
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/home',
              factory: $HomeRoute._fromState,
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/map',
              factory: $MapRoute._fromState,
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/playdates',
              factory: $PlaydatesRoute._fromState,
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/events',
              factory: $EventsRoute._fromState,
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/messages',
              factory: $MessagesRoute._fromState,
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/profile',
              factory: $ProfileRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'settings',
                  factory: $SettingsRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'social-feed',
                  factory: $ProfileSocialFeedRoute._fromState,
                ),
              ],
            ),
          ],
        ),
      ],
    );

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) =>
      const AppShellRouteData();
}

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location(
        '/home',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MapRoute on GoRouteData {
  static MapRoute _fromState(GoRouterState state) => const MapRoute();

  @override
  String get location => GoRouteData.$location(
        '/map',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PlaydatesRoute on GoRouteData {
  static PlaydatesRoute _fromState(GoRouterState state) =>
      const PlaydatesRoute();

  @override
  String get location => GoRouteData.$location(
        '/playdates',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $EventsRoute on GoRouteData {
  static EventsRoute _fromState(GoRouterState state) => const EventsRoute();

  @override
  String get location => GoRouteData.$location(
        '/events',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $MessagesRoute on GoRouteData {
  static MessagesRoute _fromState(GoRouterState state) => const MessagesRoute();

  @override
  String get location => GoRouteData.$location(
        '/messages',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileRoute on GoRouteData {
  static ProfileRoute _fromState(GoRouterState state) => const ProfileRoute();

  @override
  String get location => GoRouteData.$location(
        '/profile',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/profile/settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileSocialFeedRoute on GoRouteData {
  static ProfileSocialFeedRoute _fromState(GoRouterState state) =>
      const ProfileSocialFeedRoute();

  @override
  String get location => GoRouteData.$location(
        '/profile/social-feed',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $achievementsRoute => GoRouteData.$route(
      path: '/achievements',
      factory: $AchievementsRoute._fromState,
    );

mixin $AchievementsRoute on GoRouteData {
  static AchievementsRoute _fromState(GoRouterState state) =>
      const AchievementsRoute();

  @override
  String get location => GoRouteData.$location(
        '/achievements',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $dogDetailsByIdRoute => GoRouteData.$route(
      path: '/dog/:id',
      factory: $DogDetailsByIdRoute._fromState,
    );

mixin $DogDetailsByIdRoute on GoRouteData {
  static DogDetailsByIdRoute _fromState(GoRouterState state) =>
      DogDetailsByIdRoute(
        id: state.pathParameters['id']!,
        $extra: state.extra as Dog?,
      );

  DogDetailsByIdRoute get _self => this as DogDetailsByIdRoute;

  @override
  String get location => GoRouteData.$location(
        '/dog/${Uri.encodeComponent(_self.id)}',
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $dogDetailsRoute => GoRouteData.$route(
      path: '/dog-details',
      factory: $DogDetailsRoute._fromState,
    );

mixin $DogDetailsRoute on GoRouteData {
  static DogDetailsRoute _fromState(GoRouterState state) => DogDetailsRoute(
        startInEditMode: _$convertMapValue('start-in-edit-mode',
                state.uri.queryParameters, _$boolConverter) ??
            false,
        $extra: state.extra as Dog,
      );

  DogDetailsRoute get _self => this as DogDetailsRoute;

  @override
  String get location => GoRouteData.$location(
        '/dog-details',
        queryParams: {
          if (_self.startInEditMode != false)
            'start-in-edit-mode': _self.startInEditMode.toString(),
        },
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}

RouteBase get $createPlaydateRoute => GoRouteData.$route(
      path: '/create-playdate',
      factory: $CreatePlaydateRoute._fromState,
    );

mixin $CreatePlaydateRoute on GoRouteData {
  static CreatePlaydateRoute _fromState(GoRouterState state) =>
      CreatePlaydateRoute(
        $extra: state.extra as Dog?,
      );

  CreatePlaydateRoute get _self => this as CreatePlaydateRoute;

  @override
  String get location => GoRouteData.$location(
        '/create-playdate',
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $createEventRoute => GoRouteData.$route(
      path: '/create-event',
      factory: $CreateEventRoute._fromState,
    );

mixin $CreateEventRoute on GoRouteData {
  static CreateEventRoute _fromState(GoRouterState state) =>
      const CreateEventRoute();

  @override
  String get location => GoRouteData.$location(
        '/create-event',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $eventDetailsByIdRoute => GoRouteData.$route(
      path: '/event/:id',
      factory: $EventDetailsByIdRoute._fromState,
    );

mixin $EventDetailsByIdRoute on GoRouteData {
  static EventDetailsByIdRoute _fromState(GoRouterState state) =>
      EventDetailsByIdRoute(
        id: state.pathParameters['id']!,
      );

  EventDetailsByIdRoute get _self => this as EventDetailsByIdRoute;

  @override
  String get location => GoRouteData.$location(
        '/event/${Uri.encodeComponent(_self.id)}',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $eventDetailsRoute => GoRouteData.$route(
      path: '/event-details',
      factory: $EventDetailsRoute._fromState,
    );

mixin $EventDetailsRoute on GoRouteData {
  static EventDetailsRoute _fromState(GoRouterState state) => EventDetailsRoute(
        $extra: state.extra as dynamic,
      );

  EventDetailsRoute get _self => this as EventDetailsRoute;

  @override
  String get location => GoRouteData.$location(
        '/event-details',
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $playdateDetailsRoute => GoRouteData.$route(
      path: '/playdate-details',
      factory: $PlaydateDetailsRoute._fromState,
    );

mixin $PlaydateDetailsRoute on GoRouteData {
  static PlaydateDetailsRoute _fromState(GoRouterState state) =>
      PlaydateDetailsRoute(
        $extra: state.extra as Map<String, dynamic>,
      );

  PlaydateDetailsRoute get _self => this as PlaydateDetailsRoute;

  @override
  String get location => GoRouteData.$location(
        '/playdate-details',
      );

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}

RouteBase get $chatRoute => GoRouteData.$route(
      path: '/chat',
      factory: $ChatRoute._fromState,
    );

mixin $ChatRoute on GoRouteData {
  static ChatRoute _fromState(GoRouterState state) => ChatRoute(
        matchId: state.uri.queryParameters['match-id']!,
        recipientId: state.uri.queryParameters['recipient-id']!,
        recipientName: state.uri.queryParameters['recipient-name']!,
        recipientAvatarUrl: state.uri.queryParameters['recipient-avatar-url']!,
      );

  ChatRoute get _self => this as ChatRoute;

  @override
  String get location => GoRouteData.$location(
        '/chat',
        queryParams: {
          'match-id': _self.matchId,
          'recipient-id': _self.recipientId,
          'recipient-name': _self.recipientName,
          'recipient-avatar-url': _self.recipientAvatarUrl,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $socialFeedRoute => GoRouteData.$route(
      path: '/social-feed',
      factory: $SocialFeedRoute._fromState,
    );

mixin $SocialFeedRoute on GoRouteData {
  static SocialFeedRoute _fromState(GoRouterState state) => SocialFeedRoute(
        initialTab: _$convertMapValue(
                'initial-tab', state.uri.queryParameters, int.parse) ??
            0,
        openCreatePost: _$convertMapValue('open-create-post',
                state.uri.queryParameters, _$boolConverter) ??
            false,
      );

  SocialFeedRoute get _self => this as SocialFeedRoute;

  @override
  String get location => GoRouteData.$location(
        '/social-feed',
        queryParams: {
          if (_self.initialTab != 0) 'initial-tab': _self.initialTab.toString(),
          if (_self.openCreatePost != false)
            'open-create-post': _self.openCreatePost.toString(),
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $notificationsRoute => GoRouteData.$route(
      path: '/notifications',
      factory: $NotificationsRoute._fromState,
    );

mixin $NotificationsRoute on GoRouteData {
  static NotificationsRoute _fromState(GoRouterState state) =>
      const NotificationsRoute();

  @override
  String get location => GoRouteData.$location(
        '/notifications',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $adminRoute => GoRouteData.$route(
      path: '/admin',
      factory: $AdminRoute._fromState,
    );

mixin $AdminRoute on GoRouteData {
  static AdminRoute _fromState(GoRouterState state) => const AdminRoute();

  @override
  String get location => GoRouteData.$location(
        '/admin',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $qrScanRoute => GoRouteData.$route(
      path: '/qr-scan',
      factory: $QrScanRoute._fromState,
    );

mixin $QrScanRoute on GoRouteData {
  static QrScanRoute _fromState(GoRouterState state) => const QrScanRoute();

  @override
  String get location => GoRouteData.$location(
        '/qr-scan',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $qrCheckinRoute => GoRouteData.$route(
      path: '/checkin',
      factory: $QrCheckinRoute._fromState,
    );

mixin $QrCheckinRoute on GoRouteData {
  static QrCheckinRoute _fromState(GoRouterState state) => QrCheckinRoute(
        park: state.uri.queryParameters['park'],
        code: state.uri.queryParameters['code'],
      );

  QrCheckinRoute get _self => this as QrCheckinRoute;

  @override
  String get location => GoRouteData.$location(
        '/checkin',
        queryParams: {
          if (_self.park != null) 'park': _self.park,
          if (_self.code != null) 'code': _self.code,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
