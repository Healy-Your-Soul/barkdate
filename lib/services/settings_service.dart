import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  
  // Settings keys
  static const String _themeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _locationKey = 'location_enabled';
  static const String _privacyKey = 'privacy_mode';

  // Default values
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _privacyMode = false;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationEnabled => _locationEnabled;
  bool get privacyMode => _privacyMode;

  /// Initialize settings service - call this at app startup
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// Load all settings from storage
  Future<void> _loadSettings() async {
    try {
      // Load theme mode
      final themeIndex = _prefs.getInt(_themeKey) ?? ThemeMode.system.index;
      _themeMode = ThemeMode.values[themeIndex];

      // Load other settings
      _notificationsEnabled = _prefs.getBool(_notificationsKey) ?? true;
      _locationEnabled = _prefs.getBool(_locationKey) ?? true;
      _privacyMode = _prefs.getBool(_privacyKey) ?? false;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Update theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;
      await _prefs.setInt(_themeKey, mode.index);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Update notifications setting
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      _notificationsEnabled = enabled;
      await _prefs.setBool(_notificationsKey, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving notifications setting: $e');
    }
  }

  /// Update location setting
  Future<void> setLocationEnabled(bool enabled) async {
    try {
      _locationEnabled = enabled;
      await _prefs.setBool(_locationKey, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving location setting: $e');
    }
  }

  /// Update privacy mode
  Future<void> setPrivacyMode(bool enabled) async {
    try {
      _privacyMode = enabled;
      await _prefs.setBool(_privacyKey, enabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving privacy mode: $e');
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    try {
      await _prefs.clear();
      _themeMode = ThemeMode.system;
      _notificationsEnabled = true;
      _locationEnabled = true;
      _privacyMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }
}
