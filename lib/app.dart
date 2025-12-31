import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:barkdate/core/router/app_router.dart';
import 'package:barkdate/design_system/app_theme.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:barkdate/services/realtime_service.dart';
import 'package:barkdate/widgets/achievement_toast.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class BarkDateApp extends ConsumerStatefulWidget {
  const BarkDateApp({super.key});

  @override
  ConsumerState<BarkDateApp> createState() => _BarkDateAppState();
}

class _BarkDateAppState extends ConsumerState<BarkDateApp> {
  StreamSubscription<AchievementEvent>? _achievementSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initRealtimeService();
  }

  Future<void> _initRealtimeService() async {
    final userId = SupabaseConfig.auth.currentUser?.id;
    if (userId != null) {
      await RealtimeService().initialize(userId);
      
      // Listen for achievement events
      _achievementSubscription = RealtimeService().achievementStream.listen((event) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          showAchievementToast(
            context,
            name: event.name,
            description: event.description,
            icon: event.icon,
          );
        }
      });
    }
    
    // Listen for auth state changes to re-initialize
    SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && data.session?.user.id != null) {
        await RealtimeService().initialize(data.session!.user.id);
        _achievementSubscription?.cancel();
        _achievementSubscription = RealtimeService().achievementStream.listen((event) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            showAchievementToast(
              context,
              name: event.name,
              description: event.description,
              icon: event.icon,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _achievementSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BarkDate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
