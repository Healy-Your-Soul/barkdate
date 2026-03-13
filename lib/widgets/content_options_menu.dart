import 'package:flutter/material.dart';
import 'package:barkdate/services/moderation_service.dart';
import 'package:barkdate/widgets/report_content_sheet.dart';

/// A subtle ⋮ menu for content options including Report and Block
///
/// Usage:
/// ```dart
/// ContentOptionsMenu(
///   contentType: 'dog_profile',
///   contentId: dog.id,
///   ownerId: dog.ownerId,
///   ownerName: dog.ownerName,
/// )
/// ```
class ContentOptionsMenu extends StatelessWidget {
  final String contentType;
  final String contentId;
  final String? ownerId; // User who owns this content
  final String? ownerName; // For display in dialogs
  final String? contentPreview; // Optional preview for report
  final bool showAsIcon; // true = icon button, false = popup menu trigger
  final VoidCallback? onBlocked; // Callback after blocking
  final VoidCallback? onReported; // Callback after reporting
  final VoidCallback? onViewProfile; // Callback to view profile (optional)
  final Color? iconColor; // Override the default icon color

  const ContentOptionsMenu({
    super.key,
    required this.contentType,
    required this.contentId,
    this.ownerId,
    this.ownerName,
    this.contentPreview,
    this.showAsIcon = true,
    this.onBlocked,
    this.onReported,
    this.onViewProfile,
    this.iconColor,
  });

  Future<void> _handleBlock(BuildContext context) async {
    if (ownerId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          ownerName != null
              ? 'Block $ownerName? You won\'t see their content anymore.'
              : 'Block this user? You won\'t see their content anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ModerationService.blockUser(ownerId!);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ownerName != null
                  ? '$ownerName has been blocked'
                  : 'User blocked'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () async {
                  await ModerationService.unblockUser(ownerId!);
                },
              ),
            ),
          );
          onBlocked?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to block user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleReport(BuildContext context) async {
    final reported = await showReportSheet(
      context,
      contentType: contentType,
      contentId: contentId,
      reportedUserId: ownerId,
      contentPreview: contentPreview,
    );

    if (reported == true) {
      onReported?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: showAsIcon
          ? Icon(Icons.more_vert,
              color: iconColor ?? Colors.grey[600], size: 20)
          : null,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'profile':
            onViewProfile?.call();
            break;
          case 'report':
            _handleReport(context);
            break;
          case 'block':
            _handleBlock(context);
            break;
        }
      },
      itemBuilder: (context) => [
        if (onViewProfile != null)
          PopupMenuItem<String>(
            value: 'profile',
            child: Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                const Text('Profile'),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.orange[700], size: 20),
              const SizedBox(width: 12),
              const Text('Report'),
            ],
          ),
        ),
        if (ownerId != null)
          PopupMenuItem<String>(
            value: 'block',
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.red[400], size: 20),
                const SizedBox(width: 12),
                const Text('Block User'),
              ],
            ),
          ),
      ],
    );
  }
}

/// Helper function to show options in a bottom sheet (alternative to popup)
Future<void> showContentOptionsSheet(
  BuildContext context, {
  required String contentType,
  required String contentId,
  String? ownerId,
  String? ownerName,
  String? contentPreview,
  VoidCallback? onBlocked,
  VoidCallback? onReported,
  VoidCallback? onViewProfile,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Profile option (if provided)
          if (onViewProfile != null)
            ListTile(
              leading: Icon(Icons.person_outline, color: Colors.blue[700]),
              title: const Text('Profile'),
              subtitle: Text(
                  'View this \${contentType}\'s profile'), // Escape interpolation for tool
              onTap: () {
                Navigator.pop(context);
                onViewProfile();
              },
            ),

          // Report option
          ListTile(
            leading: Icon(Icons.flag_outlined, color: Colors.orange[700]),
            title: const Text('Report'),
            subtitle: Text('Report this $contentType'),
            onTap: () async {
              Navigator.pop(context);
              final reported = await showReportSheet(
                context,
                contentType: contentType,
                contentId: contentId,
                reportedUserId: ownerId,
                contentPreview: contentPreview,
              );
              if (reported == true) onReported?.call();
            },
          ),

          // Block option
          if (ownerId != null)
            ListTile(
              leading: Icon(Icons.block, color: Colors.red[400]),
              title: const Text('Block User'),
              subtitle: Text(ownerName != null
                  ? 'Hide all content from $ownerName'
                  : 'Hide all content from this user'),
              onTap: () async {
                Navigator.pop(context);

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Block User'),
                    content: Text(
                      ownerName != null
                          ? 'Block $ownerName? You won\'t see their content anymore.'
                          : 'Block this user? You won\'t see their content anymore.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Block'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  final success = await ModerationService.blockUser(ownerId);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ownerName != null
                            ? '$ownerName has been blocked'
                            : 'User blocked'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    onBlocked?.call();
                  }
                }
              },
            ),

          const SizedBox(height: 8),

          // Cancel
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
