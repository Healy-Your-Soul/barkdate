import 'package:feature_flags_toggly/feature_flags_toggly.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to manage feature flags using Toggly.
class FeatureFlags {
  // Define feature flag keys
  static const String slimBottomNav = 'slim_bottom_nav';

  // Local cache for synchronous access
  static Map<String, bool> _localCache = {};

  /// Initialize Toggly with configuration.
  /// For now, since login is not required, we can initialize with defaults or offline mode if supported,
  /// or simply rely on the fact that we can mock it in tests.
  /// The library documentation suggests `Toggly.init(...)`.
  static Future<void> init() async {
    // Basic initialization.
    // Ensure you have a valid App Key or use a development key.
    // If no key is provided, it might default to false.
    // We can set default values for development if the library supports it,
    // or we might need a real key.
    await Toggly.init(
      appKey: null,
      environment: 'Production',
      flagDefaults: {
        slimBottomNav: true,
      },
    );

    // Clear any existing cache to ensure we use the provided defaults
    // This prevents stale values from persisting when we change defaults in code
    await Toggly.clearFeatureFlagsCache();

    // Pre-cache values to allow synchronous access
    _localCache = await Toggly.cachedFeatureFlags;
  }

  /// Wrapper to check if slim bottom nav is enabled.
  /// Defaults to [defaultValue] if flag is missing.
  bool get useSlimBottomNav {
    return _localCache[slimBottomNav] ?? false;
  }
}

/// Provider to access feature flags.
/// This allows overriding the FeatureFlags instance in tests.
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags();
});
