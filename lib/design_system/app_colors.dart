import 'package:flutter/material.dart';

/// Airbnb-inspired color system for BarkDate
/// Clean, modern, and dog-friendly palette
class AppColors {
  // Primary Colors - Green (nature, parks, outdoors)
  static const Color primaryGreen = Color(0xFF2D7D32);
  static const Color primaryGreenLight = Color(0xFF4CAF50);
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  
  // Secondary Colors - Warm Brown (earthy, friendly)
  static const Color secondaryBrown = Color(0xFF8D6E63);
  static const Color secondaryBrownLight = Color(0xFFBCAAA4);
  static const Color secondaryBrownDark = Color(0xFF5D4037);
  
  // Accent Colors
  static const Color accentOrange = Color(0xFFFF8A65);
  static const Color accentBlue = Color(0xFF42A5F5);
  static const Color accentPurple = Color(0xFF7E57C2);
  
  // Neutral Colors - Light Mode
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFEEEEEE);
  
  // Text Colors - Light Mode
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextTertiary = Color(0xFF9E9E9E);
  
  // Neutral Colors - Dark Mode
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkBorder = Color(0xFF3A3A3A);
  static const Color darkDivider = Color(0xFF2A2A2A);
  
  // Text Colors - Dark Mode
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF808080);
  
  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  
  // Overlay Colors
  static Color overlayLight = Colors.black.withValues(alpha: 0.05);
  static Color overlayMedium = Colors.black.withValues(alpha: 0.1);
  static Color overlayDark = Colors.black.withValues(alpha: 0.2);
  static Color overlayHeavy = Colors.black.withValues(alpha: 0.4);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreenLight, primaryGreen],
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentOrange, Color(0xFFFF6F4C)],
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, Color(0xFF1E88E5)],
  );
}
