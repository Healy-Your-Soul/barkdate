import 'package:flutter/material.dart';
import 'package:barkdate/design_system/app_spacing.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/widgets/app_button.dart';

/// Empty state component (like Airbnb's empty states)
/// Friendly, helpful empty states with clear actions
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? customAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenMargin,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            
            AppSpacing.verticalSpaceXXL,
            
            // Title
            Text(
              title,
              style: AppTypography.h3(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            
            AppSpacing.verticalSpaceMD,
            
            // Message
            Text(
              message,
              style: AppTypography.bodyMedium(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            
            AppSpacing.verticalSpaceXXL,
            
            // Action button
            if (customAction != null)
              customAction!
            else if (actionText != null && onAction != null)
              AppButton(
                text: actionText!,
                onPressed: onAction,
                type: AppButtonType.primary,
                size: AppButtonSize.large,
              ),
          ],
        ),
      ),
    );
  }
}

/// Loading state with skeleton loaders
class AppLoadingState extends StatelessWidget {
  final int itemCount;

  const AppLoadingState({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.screenMargin,
      itemCount: itemCount,
      itemBuilder: (context, index) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark 
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          AppSpacing.verticalSpaceMD,
          
          // Title placeholder
          Container(
            height: 20,
            width: double.infinity,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          AppSpacing.verticalSpaceSM,
          
          // Subtitle placeholder
          Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
