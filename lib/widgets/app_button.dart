import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_styles.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/design_system/app_colors.dart';

/// Airbnb-style button components
/// Consistent button styling with clear hierarchy

enum AppButtonSize { small, medium, large }
enum AppButtonType { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonSize size;
  final AppButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Size configuration
    final double height = switch (size) {
      AppButtonSize.small => 36.0,
      AppButtonSize.medium => 48.0,
      AppButtonSize.large => 56.0,
    };
    
    final EdgeInsets padding = switch (size) {
      AppButtonSize.small => const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      AppButtonSize.medium => const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      AppButtonSize.large => const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
    };
    
    final double fontSize = switch (size) {
      AppButtonSize.small => 14.0,
      AppButtonSize.medium => 16.0,
      AppButtonSize.large => 18.0,
    };

    // Build button content
    Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                type == AppButtonType.primary ? Colors.white : AppColors.primaryGreen,
              ),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );

    // Build button based on type
    Widget button = switch (type) {
      AppButtonType.primary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: customColor ?? AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: padding,
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: AppStyles.borderRadiusSM,
          ),
        ),
        child: buttonContent,
      ),
      
      AppButtonType.secondary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: padding,
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: AppStyles.borderRadiusSM,
          ),
        ),
        child: buttonContent,
      ),
      
      AppButtonType.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: customColor ?? AppColors.primaryGreen,
          side: BorderSide(
            color: customColor ?? AppColors.primaryGreen,
            width: 1.5,
          ),
          padding: padding,
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: AppStyles.borderRadiusSM,
          ),
        ),
        child: buttonContent,
      ),
      
      AppButtonType.text => TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: customColor ?? AppColors.primaryGreen,
          padding: padding,
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: AppStyles.borderRadiusSM,
          ),
        ),
        child: buttonContent,
      ),
    };

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

/// Icon button with consistent styling
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool hasBorder;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 40.0,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: size,
      height: size,
      decoration: hasBorder
          ? BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            )
          : null,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        color: color ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        iconSize: size * 0.5,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Floating action button with consistent styling
class AppFAB extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final bool isExtended;

  const AppFAB({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.backgroundColor,
    this.isExtended = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isExtended && label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: Icon(icon),
        label: Text(
          label!,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      child: Icon(icon),
    );
  }
}
