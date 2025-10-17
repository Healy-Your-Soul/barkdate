import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_styles.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/design_system/app_colors.dart';

/// Airbnb-style bottom sheet
/// Consistent modal presentation across the app
class AppBottomSheet {
  /// Show a standard bottom sheet with handle bar
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    double? height,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => AppBottomSheetContent(
        title: title,
        height: height,
        child: child,
      ),
    );
  }
}

class AppBottomSheetContent extends StatelessWidget {
  final Widget child;
  final String? title;
  final double? height;

  const AppBottomSheetContent({
    super.key,
    required this.child,
    this.title,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: height ?? screenHeight * 0.75,
      decoration: AppStyles.bottomSheetDecoration(isDark: isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.md),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title (if provided)
          if (title != null) ...[
            AppSpacing.verticalSpaceLG,
            Padding(
              padding: AppSpacing.horizontalXXL,
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            AppSpacing.verticalSpaceLG,
            Divider(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              height: 1,
            ),
          ] else
            AppSpacing.verticalSpaceMD,
          
          // Content
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Scrollable bottom sheet content wrapper
class AppBottomSheetScrollable extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const AppBottomSheetScrollable({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding ?? AppSpacing.screenMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
