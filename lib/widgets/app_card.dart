import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_styles.dart';
import 'package:barkdate/design_system/app_spacing.dart';

/// Airbnb-style card component
/// Consistent card styling across the entire app
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.onTap,
    this.borderRadius,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final cardWidget = Container(
      margin: margin ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: borderRadius ?? AppStyles.borderRadiusMD,
        boxShadow: boxShadow ?? AppStyles.shadowMD,
        border: border,
      ),
      child: Padding(
        padding: padding ?? AppSpacing.cardPadding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? AppStyles.borderRadiusMD,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}

/// Image card with Airbnb-style photo presentation
class AppImageCard extends StatelessWidget {
  final String? imageUrl;
  final Widget? child;
  final double? height;
  final double? width;
  final BoxFit fit;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Widget? overlay;
  final List<Widget>? badges;

  const AppImageCard({
    super.key,
    this.imageUrl,
    this.child,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.onTap,
    this.borderRadius,
    this.overlay,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget content = Container(
      height: height ?? 200,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: borderRadius ?? AppStyles.borderRadiusMD,
        boxShadow: AppStyles.shadowSM,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? AppStyles.borderRadiusMD,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                  child: const Icon(Icons.image, size: 48, color: Colors.grey),
                ),
              )
            else
              Container(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                child: const Icon(Icons.image, size: 48, color: Colors.grey),
              ),
            
            // Overlay
            if (overlay != null) overlay!,
            
            // Badges (top-right corner)
            if (badges != null && badges!.isNotEmpty)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: badges!,
                ),
              ),
            
            // Child content (bottom overlay)
            if (child != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: child!,
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? AppStyles.borderRadiusMD,
        child: content,
      );
    }

    return content;
  }
}

/// Compact info card (for dashboard items)
class AppInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? badge;

  const AppInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? Theme.of(context).colorScheme.primary;
    
    return AppCard(
      onTap: onTap,
      padding: AppSpacing.paddingLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.1),
                  borderRadius: AppStyles.borderRadiusSM,
                ),
                child: Icon(
                  icon,
                  color: cardColor,
                  size: 24,
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          AppSpacing.verticalSpaceMD,
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.verticalSpaceXS,
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
