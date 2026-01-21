import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/services/dog_sharing_service.dart';
import 'package:barkdate/design_system/app_typography.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class AcceptShareScreen extends ConsumerStatefulWidget {
  final String? initialCode;

  const AcceptShareScreen({super.key, this.initialCode});

  @override
  ConsumerState<AcceptShareScreen> createState() => _AcceptShareScreenState();
}

class _AcceptShareScreenState extends ConsumerState<AcceptShareScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _requiresPin = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
    }
  }

  Future<void> _submitCode() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    if (_codeController.text.isEmpty) {
      setState(() => _error = 'Please enter a share code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await DogSharingService.acceptShare(
        shareCode: _codeController.text.trim().toUpperCase(),
        userId: user.id,
        pinCode: _requiresPin ? _pinController.text : null,
      );

      if (!mounted) return;

      if (result.success) {
        // Success!
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Close screen
        // Optionally refresh profile or navigate to dog details
      } else {
        // Handle specific errors
        if (result.message.contains('PIN')) {
          setState(() {
            _requiresPin = true;
            _error = 'This share requires a PIN code';
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error accepting share: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Dog'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Enter Share Code',
              style: AppTypography.h2(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 8-character code shared by the dog owner.',
              style: AppTypography.bodySmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Share Code',
                hintText: 'e.g. ABC123XY',
                border: const OutlineInputBorder(),
                errorText: _requiresPin ? null : _error,
                prefixIcon: const Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _error = null),
            ),
            
            if (_requiresPin) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                decoration: InputDecoration(
                  labelText: 'PIN Code',
                  hintText: 'Enter 6-digit PIN',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  prefixIcon: const Icon(Icons.lock),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_requiresPin ? 'Verify PIN & Connect' : 'Connect'),
            ),
          ],
        ),
      ),
      ), // Close GestureDetector
    );
  }
}
