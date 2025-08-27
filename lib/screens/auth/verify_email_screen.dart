import 'package:flutter/material.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  String? _message;

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      await SupabaseConfig.auth.refreshSession();
      final user = SupabaseConfig.auth.currentUser;
      final confirmed = user?.emailConfirmedAt != null;
      if (confirmed) {
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _message = 'Not verified yet. Please click the email link, then tap Check again.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Could not check yet. Try again in a moment.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Verify your email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We sent a verification link to:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.email, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
              'Open your inbox and tap the link to verify. Once done, come back and press “I\'ve verified”.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const Spacer(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!, style: TextStyle(color: theme.colorScheme.tertiary)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkVerified,
                child: _checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("I've verified"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


