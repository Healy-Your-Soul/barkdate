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
      
      // If no user or not confirmed, try refreshing session
      if (user == null || user.emailConfirmedAt == null) {
        try {
          await SupabaseConfig.auth.refreshSession();
          user = SupabaseConfig.auth.currentUser;
        } catch (refreshError) {
          // Refresh failed, but continue with current user check
          debugPrint('Refresh session failed: $refreshError');
        }
      }
      
      final confirmed = user?.emailConfirmedAt != null;
      debugPrint('Verification check - User: ${user?.id}, Confirmed: $confirmed');
      
      if (confirmed && user != null) {
        if (mounted) {
          // Email verified! Check if user has completed profile setup
          final currentUser = user; // Already checked non-null above
          final hasProfile = await _checkUserProfile(currentUser.id);
          if (hasProfile) {
            // Profile exists, go to main app
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigation()),
            );
          } else {
            // Profile doesn't exist, go to profile creation
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => CreateProfileScreen(
                  userName: currentUser.userMetadata?['name'] ?? '',
                  userEmail: currentUser.email ?? '',
                  userId: currentUser.id,
                ),
              ),
            );
          }
        }
      } else {
        setState(() {
          _message = user == null 
              ? 'No user session found. Please sign in again.'
              : 'Not verified yet. Please click the email link, then tap "I\'ve verified".';
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resending ? null : _resendEmail,
                child: _resending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Resend Email"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


