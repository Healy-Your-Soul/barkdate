import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to handle automatic app updates using Shorebird (code push)
/// and a custom Supabase-backed version checker for major updates.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final _shorebirdUpdater = ShorebirdUpdater();
  
  // Cache for update config
  Map<String, dynamic>? _updateConfig;
  String? _currentVersion;

  /// Initialize the update service.
  /// This should be called during app startup.
  Future<void> initialize() async {
    if (kIsWeb) return; // Web doesn't need this kind of update logic

    // 1. Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    debugPrint('🚀 Current App Version: $_currentVersion');

    // 2. Check for Shorebird patches in the background
    _checkShorebirdPatches();

    // 3. Fetch remote config for major updates
    await fetchUpdateConfig();
  }

  /// Check for and download Shorebird patches.
  Future<void> _checkShorebirdPatches() async {
    try {
      final isShorebirdAvailable = _shorebirdUpdater.isAvailable;
      if (!isShorebirdAvailable) {
        debugPrint('ℹ️ Shorebird is not available on this device/build.');
        return;
      }

      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('📥 New Shorebird patch available! Downloading...');
        await _shorebirdUpdater.update();
        debugPrint('✅ Shorebird patch downloaded. It will be applied on next restart.');
      } else if (status == UpdateStatus.restartRequired) {
        debugPrint('🔄 Shorebird patch already downloaded. Restart required.');
      } else {
        debugPrint('✨ App is up to date with the latest patches.');
      }
    } catch (e) {
      debugPrint('❌ Error checking for Shorebird updates: $e');
    }
  }

  /// Fetch the latest update configuration from Supabase.
  Future<void> fetchUpdateConfig() async {
    try {
      final response = await SupabaseConfig.client
          .from('app_config')
          .select('value')
          .eq('key', 'update_config')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        _updateConfig = Map<String, dynamic>.from(response['value']);
        debugPrint('📡 Update Config Fetched: $_updateConfig');
      }
    } catch (e) {
      debugPrint('❌ Error fetching update config: $e');
    }
  }

  /// Returns true if a major update is required (blocking).
  bool isUpdateRequired() {
    if (_updateConfig == null || _currentVersion == null) return false;
    
    final minRequired = _updateConfig!['min_required_version'] as String;
    return _isVersionOlder(_currentVersion!, minRequired);
  }

  /// Returns true if a new version is available (non-blocking).
  bool isUpdateAvailable() {
    if (_updateConfig == null || _currentVersion == null) return false;
    
    final latest = _updateConfig!['latest_version'] as String;
    return _isVersionOlder(_currentVersion!, latest);
  }

  String get updateMessage => _updateConfig?['message'] ?? 'A new version is available!';

  /// Launch the appropriate update URL (App Store, Play Store, or direct APK).
  Future<void> launchUpdateUrl() async {
    if (_updateConfig == null) return;

    String? url;
    if (Platform.isAndroid) {
      url = _updateConfig!['android_url'];
    } else if (Platform.isIOS) {
      url = _updateConfig!['ios_url'];
    }

    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Helper to compare semantic versions (e.g., "1.0.0" < "1.1.0").
  bool _isVersionOlder(String current, String target) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final targetParts = target.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final targetPart = i < targetParts.length ? targetParts[i] : 0;

      if (currentPart < targetPart) return true;
      if (currentPart > targetPart) return false;
    }
    return false;
  }
}
