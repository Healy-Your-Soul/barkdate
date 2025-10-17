import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// Airbnb-inspired style constants
/// Border radius, shadows, and other visual properties
class AppStyles {
  // Border Radius (rounded corners like Airbnb)
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusFull = 999.0; // Fully rounded
  
  // BorderRadius objects
  static const BorderRadius borderRadiusXS = BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderRadiusSM = BorderRadius.all(Radius.circular(radiusSM));
  static const BorderRadius borderRadiusMD = BorderRadius.all(Radius.circular(radiusMD));
  static const BorderRadius borderRadiusLG = BorderRadius.all(Radius.circular(radiusLG));
  static const BorderRadius borderRadiusXL = BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius borderRadiusXXL = BorderRadius.all(Radius.circular(radiusXXL));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));
  
  // Top-only border radius (for sheets, modals)
  static const BorderRadius borderRadiusTopMD = BorderRadius.vertical(top: Radius.circular(radiusMD));
  static const BorderRadius borderRadiusTopLG = BorderRadius.vertical(top: Radius.circular(radiusLG));
  static const BorderRadius borderRadiusTopXL = BorderRadius.vertical(top: Radius.circular(radiusXL));
  
  // Elevation / Shadows (subtle like Airbnb)
  static List<BoxShadow> get shadowSM => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  
  static List<BoxShadow> get shadowMD => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 2),
      blurRadius: 8,
    ),
  ];
  
  static List<BoxShadow> get shadowLG => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];
  
  static List<BoxShadow> get shadowXL => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];
  
  // Card decoration (Airbnb-style)
  static BoxDecoration cardDecoration({
    Color? color,
    bool isDark = false,
  }) => BoxDecoration(
    color: color ?? (isDark ? AppColors.darkSurface : AppColors.lightSurface),
    borderRadius: borderRadiusMD,
    boxShadow: shadowMD,
  );
  
  // Image card decoration (for photos)
  static BoxDecoration imageCardDecoration({
    String? imageUrl,
    bool isDark = false,
  }) => BoxDecoration(
    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
    borderRadius: borderRadiusMD,
    boxShadow: shadowSM,
    image: imageUrl != null
        ? DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          )
        : null,
  );
  
  // Bottom sheet decoration
  static BoxDecoration bottomSheetDecoration({
    bool isDark = false,
  }) => BoxDecoration(
    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    borderRadius: borderRadiusTopXL,
    boxShadow: shadowXL,
  );
  
  // Input decoration (text fields)
  static InputDecoration inputDecoration({
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDark = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: borderRadiusSM,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusSM,
      borderSide: BorderSide(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusSM,
      borderSide: const BorderSide(
        color: AppColors.primaryGreen,
        width: 2,
      ),
    ),
    contentPadding: AppSpacing.paddingLG,
  );
  
  // Divider
  static Divider divider({bool isDark = false}) => Divider(
    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
    height: 1,
    thickness: 1,
  );
  
  // Border
  static Border border({bool isDark = false}) => Border.all(
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    width: 1,
  );
  
  // Animation durations (smooth like Airbnb)
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Curves
  static const Curve animationCurve = Curves.easeInOut;
  static const Curve animationCurveEmphasized = Curves.easeOutCubic;
}
