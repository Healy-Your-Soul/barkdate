import 'package:flutter/material.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/screens/main_navigation.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _message;

  Future<void> _resendEmail() async {
    setState(() {
      _resending = true;
      _message = null;
    });

    try {
      await SupabaseConfig.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      setState(() {
        _message = 'Verification email sent! Check your inbox.';
      });
    } catch (e) {
      setState(() {
        _message = 'Failed to resend email. Try again later.';
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      // First try to get current user without forcing refresh
      var user = SupabaseConfig.auth.currentUser;
      debugPrint(
          'Initial user check - User: ${user?.id}, Email confirmed: ${user?.emailConfirmedAt != null}');

      // If no user session exists, user needs to sign in again
      if (user == null) {
        setState(() {
          _message =
              'Session expired. Please sign in again to verify your email.';
        });

        // Optional: Navigate back to sign in after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context)
                .pop(); // Go back to previous screen (likely sign in)
          }
        });
        return;
      }

      // Check if already verified
      if (user.emailConfirmedAt != null) {
        debugPrint('User already verified, proceeding to app');
        if (mounted) {
          // Email verified! Check if user has completed profile setup
          final nav = Navigator.of(context);
          final hasProfile = await _checkUserProfile(user.id);
          if (!mounted) return;
          if (hasProfile) {
            nav.pushReplacement(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          } else {
            nav.pushReplacement(
              MaterialPageRoute(
                builder: (context) => CreateProfileScreen(
                  userName: user?.userMetadata?['name'] ?? '',
                  userEmail: user?.email ?? '',
                  userId: user?.id ?? '',
                ),
              ),
            );
          }
        }
        return;
      }

      // User exists but not verified - try refreshing session to check for verification
      try {
        debugPrint('User not verified, trying to refresh session...');
        await SupabaseConfig.auth.refreshSession();
        user = SupabaseConfig.auth.currentUser;
        debugPrint(
            'After refresh - User: ${user?.id}, Email confirmed: ${user?.emailConfirmedAt != null}');

        if (user?.emailConfirmedAt != null) {
          // Now verified! Proceed to app
          if (mounted) {
            final nav = Navigator.of(context);
            final hasProfile = await _checkUserProfile(user!.id);
            if (!mounted) return;
            if (hasProfile) {
              nav.pushReplacement(
                MaterialPageRoute(builder: (context) => const MainNavigation()),
              );
            } else {
              nav.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => CreateProfileScreen(
                    userName: user?.userMetadata?['name'] ?? '',
                    userEmail: user?.email ?? '',
                    userId: user?.id ?? '',
                  ),
                ),
              );
            }
          }
        } else {
          // Still not verified
          setState(() {
            _message =
                'Not verified yet. Please click the email link, then tap "I\'ve verified".';
          });
        }
      } catch (refreshError) {
        debugPrint('Refresh session failed: $refreshError');
        setState(() {
          _message =
              'Could not verify email status. Please click the email link first, then try again.';
        });
      }
    } catch (e) {
      debugPrint('Verification check error: $e');
      setState(() {
        _message = 'Could not check verification status. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<bool> _checkUserProfile(String userId) async {
    try {
      final profile = await SupabaseService.selectSingle(
        'users',
        filters: {'id': userId},
      );
      return profile != null;
    } catch (e) {
      return false;
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
            Text('We sent a verification link to:',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.email,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(
              'Open your inbox and tap the link to verify. Once done, come back and press “I\'ve verified”.',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const Spacer(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!,
                    style: TextStyle(color: theme.colorScheme.tertiary)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkVerified,
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text("I've verified"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resending ? null : _resendEmail,
                child: _resending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Resend Email"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
