import 'package:flutter/material.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/core/router/app_routes.dart';
import 'package:barkdate/design_system/app_typography.dart';
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

        // Navigate back to sign in after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            const AuthRoute().go(context);
          }
        });
        return;
      }

      // Check if already verified
      if (user.emailConfirmedAt != null) {
        debugPrint('User already verified, proceeding to app');
        if (mounted) {
          // Email verified! Route through SupabaseAuthWrapper which
          // handles profile status check and onboarding routing.
          const SplashRoute().go(context);
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
          // Now verified! Route through SupabaseAuthWrapper
          if (mounted) {
            const SplashRoute().go(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your email',
              style: AppTypography.display2(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'We sent a verification link to:',
              style: AppTypography.bodyLarge(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.email,
              style: AppTypography.h3(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Open your inbox and tap the link to verify. Once done, come back and press "I\'ve verified".',
              style: AppTypography.bodyMedium(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _message!,
                  style: AppTypography.bodySmall(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _checking ? null : _checkVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFECECEC),
                  disabledForegroundColor: const Color(0xFFB6B6B6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _checking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(
                        "I've verified",
                        style: AppTypography.button(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _resending ? null : _resendEmail,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: const Color(0xFFECECEC),
                    width: 1.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _resending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(
                        'Resend Email',
                        style: AppTypography.button(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
