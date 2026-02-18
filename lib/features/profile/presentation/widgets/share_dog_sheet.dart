import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barkdate/services/dog_sharing_service.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class ShareDogSheet extends ConsumerStatefulWidget {
  final String dogId;
  final String dogName;

  const ShareDogSheet({
    super.key,
    required this.dogId,
    required this.dogName,
  });

  @override
  ConsumerState<ShareDogSheet> createState() => _ShareDogSheetState();
}

class _ShareDogSheetState extends ConsumerState<ShareDogSheet> {
  DogAccessLevel _selectedAccess = DogAccessLevel.view;
  bool _isLoading = false;
  DogShareResult? _shareResult;
  final TextEditingController _pinController = TextEditingController();
  bool _usePin = false;

  Future<void> _generateShareLink() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await DogSharingService.createShare(
        dogId: widget.dogId,
        ownerId: user.id,
        accessLevel: _selectedAccess,
        pinCode: _usePin && _pinController.text.isNotEmpty
            ? _pinController.text
            : null,
      );

      if (mounted) {
        setState(() {
          _shareResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating share link: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_shareResult == null) return;
    Clipboard.setData(ClipboardData(text: _shareResult!.shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share ${widget.dogName}\'s Profile',
              style: AppTypography.h3(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_shareResult == null) ...[
              Text(
                'Select Access Level',
                style: AppTypography.bodySmall()
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildAccessOption(
                DogAccessLevel.view,
                'View Only',
                'Can see profile, stats, and schedule',
                Icons.visibility_outlined,
              ),
              _buildAccessOption(
                DogAccessLevel.edit,
                'Edit',
                'Can update info and add notes',
                Icons.edit_outlined,
              ),
              _buildAccessOption(
                DogAccessLevel.manage,
                'Manage',
                'Full control (check-ins, booking)',
                Icons.settings_outlined,
              ),
              const SizedBox(height: 24),

              // PIN Option
              Row(
                children: [
                  Checkbox(
                    value: _usePin,
                    onChanged: (val) => setState(() => _usePin = val ?? false),
                  ),
                  const Text('Require PIN Code'),
                ],
              ),
              if (_usePin)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 16),
                  child: TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-digit PIN',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateShareLink,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Generate Share Link'),
              ),
            ] else ...[
              // Result View
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Link Generated!',
                      style: AppTypography.h3().copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this code with your trainer or walker:',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _shareResult!.shareCode,
                        style: AppTypography.h2().copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Placeholder for WhatsApp share
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('WhatsApp sharing coming in Phase 4!')),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ), // Close GestureDetector
    );
  }

  Widget _buildAccessOption(
    DogAccessLevel level,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedAccess == level;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedAccess = level),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
