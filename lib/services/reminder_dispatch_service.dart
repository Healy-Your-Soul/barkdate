import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/supabase/bark_playdate_services.dart';

/// Periodically dispatches due playdate reminders.
class ReminderDispatchService {
  ReminderDispatchService._();
  static final ReminderDispatchService _instance = ReminderDispatchService._();
  factory ReminderDispatchService() => _instance;

  Timer? _timer;
  bool _isRunning = false;

  void start() {
    if (_timer != null) return;

    // Trigger once on startup.
    unawaited(_tick());

    // Keep checking in short intervals for near-term reminder windows.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_tick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_isRunning) return;

    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    _isRunning = true;
    try {
      final sent = await PlaydateRequestService.processDueReminderNotifications();
      if (sent > 0) {
        debugPrint('⏰ Reminder dispatcher sent $sent notification(s)');
      }
    } catch (e) {
      debugPrint('❌ Reminder dispatcher error: $e');
    } finally {
      _isRunning = false;
    }
  }
}
