import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/core/router/app_router.dart';
import 'package:barkdate/design_system/app_theme.dart';
import 'package:barkdate/services/settings_service.dart';

class BarkDateApp extends ConsumerWidget {
  const BarkDateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BarkDate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Or use a provider to control this
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
