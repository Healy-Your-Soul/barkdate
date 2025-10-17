import 'package:flutter/material.dart';

/// Mobile-first responsive design system for BarkDate
/// Provides adaptive spacing, sizing, and layout helpers
class AppResponsive {
  // Screen size breakpoints (mobile-first)
  static const double mobileMaxWidth = 360.0;  // Small phones
  static const double tabletMinWidth = 600.0;   // Tablets
  static const double desktopMinWidth = 1024.0; // Desktop

  /// Get current screen type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < tabletMinWidth) return ScreenType.mobile;
    if (width < desktopMinWidth) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletMinWidth;
  }

  /// Check if current screen is small mobile (< 360px)
  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileMaxWidth;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMinWidth && width < desktopMinWidth;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMinWidth;
  }

  /// Adaptive spacing based on screen size
  static double spacing(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.25;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.5;
    }
  }

  /// Adaptive horizontal padding for screen edges
  static EdgeInsets screenPadding(BuildContext context) {
    if (isSmallMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12);
    } else if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 16);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 32);
    }
  }

  /// Adaptive card padding
  static EdgeInsets cardPadding(BuildContext context) {
    if (isSmallMobile(context)) {
      return const EdgeInsets.all(10);
    } else if (isMobile(context)) {
      return const EdgeInsets.all(12);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  /// Adaptive grid columns
  static int gridColumns(BuildContext context) {
    if (isMobile(context)) return 2;
    if (isTablet(context)) return 3;
    return 4;
  }

  /// Adaptive font size scaling
  static double fontSize(BuildContext context, double baseSize) {
    if (isSmallMobile(context)) {
      return baseSize * 0.9; // Slightly smaller on small screens
    }
    return baseSize;
  }

  /// Adaptive icon size
  static double iconSize(BuildContext context, double baseSize) {
    if (isSmallMobile(context)) {
      return baseSize * 0.85;
    }
    return baseSize;
  }

  /// Adaptive avatar radius
  static double avatarRadius(BuildContext context, double baseRadius) {
    if (isSmallMobile(context)) {
      return baseRadius * 0.85;
    }
    return baseRadius;
  }

  /// Adaptive button height
  static double buttonHeight(BuildContext context) {
    if (isSmallMobile(context)) return 40;
    if (isMobile(context)) return 44;
    return 48;
  }

  /// Adaptive horizontal list item width
  static double horizontalCardWidth(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.3;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.5;
    }
  }

  /// Adaptive horizontal list item height
  static double horizontalCardHeight(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile * 1.2;
      case ScreenType.desktop:
        return desktop ?? mobile * 1.4;
    }
  }

  /// Get safe width for horizontal scrolling items
  /// Ensures items don't cause overflow on small screens
  static double safeHorizontalItemWidth(BuildContext context, double preferredWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenPadding(context).horizontal;
    final maxWidth = screenWidth - padding - 32; // Account for spacing
    return preferredWidth.clamp(0, maxWidth);
  }

  /// Get maximum lines for text based on screen size
  static int maxLines(BuildContext context, {int mobile = 2, int tablet = 3}) {
    return isMobile(context) ? mobile : tablet;
  }
}

/// Screen type enum
enum ScreenType {
  mobile,
  tablet,
  desktop,
}

/// Extension on BuildContext for easier access
extension ResponsiveContext on BuildContext {
  bool get isMobile => AppResponsive.isMobile(this);
  bool get isSmallMobile => AppResponsive.isSmallMobile(this);
  bool get isTablet => AppResponsive.isTablet(this);
  bool get isDesktop => AppResponsive.isDesktop(this);
  ScreenType get screenType => AppResponsive.getScreenType(this);
  
  EdgeInsets get screenPadding => AppResponsive.screenPadding(this);
  EdgeInsets get cardPadding => AppResponsive.cardPadding(this);
}
