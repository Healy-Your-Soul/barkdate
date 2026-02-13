import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:barkdate/services/qr_checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

/// Screen for handling QR code check-ins (via deep link or web)
class QrCheckInScreen extends StatefulWidget {
  final String? parkId;
  final String? code;

  const QrCheckInScreen({
    super.key,
    this.parkId,
    this.code,
  });

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  bool _isProcessing = true;
  bool _success = false;
  String? _parkName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processCheckIn();
  }

  Future<void> _processCheckIn() async {
    // Check if user is logged in
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Please sign in to check in';
      });
      return;
    }

    // Check if we have the required parameters
    if (widget.parkId == null || widget.code == null) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Invalid check-in link';
      });
      return;
    }

    // Validate and process the check-in
    final result = await QrCheckInService.processQrCheckIn(
      qrData: 'https://barkdate.app/checkin?park=${widget.parkId}&code=${widget.code}',
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _success = result.success;
        _parkName = result.park?.name;
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _goToMap() {
    context.go('/map');
  }

  void _signIn() {
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _isProcessing
                ? _buildProcessing()
                : _success
                    ? _buildSuccess()
                    : _buildError(),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Checking you in...',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          '🐕 Wagging tail with excitement!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Woof! You\'re checked in!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _parkName ?? 'Unknown Park',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '🐾 Have fun playing!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _goToMap,
            icon: const Icon(Icons.map),
            label: const Text('View on Map'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    final isAuthError = _errorMessage?.contains('sign in') ?? false;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAuthError ? Icons.login : Icons.error_outline,
            color: Colors.orange,
            size: 80,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          isAuthError ? 'Sign in Required' : 'Oops!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Failed to check in',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isAuthError ? _signIn : _goToMap,
            icon: Icon(isAuthError ? Icons.login : Icons.map),
            label: Text(isAuthError ? 'Sign In' : 'Go to Map'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        if (!isAuthError) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: _processCheckIn,
            child: const Text('Try Again'),
          ),
        ],
      ],
    );
  }
}
