import 'package:flutter/material.dart';
import 'package:barkdate/models/checkin.dart';
import 'package:barkdate/services/checkin_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';

class CheckInButton extends StatefulWidget {
  final String parkId;
  final String parkName;
  final double? latitude;
  final double? longitude;
  final VoidCallback? onCheckInSuccess;
  final VoidCallback? onCheckOutSuccess;
  final bool isFloating;

  const CheckInButton({
    super.key,
    required this.parkId,
    required this.parkName,
    this.latitude,
    this.longitude,
    this.onCheckInSuccess,
    this.onCheckOutSuccess,
    this.isFloating = false,
  });

  @override
  State<CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<CheckInButton> {
  CheckIn? _activeCheckIn;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadActiveCheckIn();
  }

  Future<void> _loadActiveCheckIn() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted) {
        setState(() {
          _activeCheckIn = checkIn;
        });
      }
    } catch (e) {
      debugPrint('Error loading active check-in: $e');
    }
  }

  Future<void> _handleCheckIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('Please sign in to check in');
        return;
      }

      // Check if user has a dog profile
      final dogs = await SupabaseConfig.client
          .from('dogs')
          .select('id')
          .eq('user_id', user.id)
          .limit(1);

      if (dogs.isEmpty) {
        _showErrorSnackBar('Please create a dog profile first');
        return;
      }

      final checkIn = await CheckInService.checkInAtPark(
        parkId: widget.parkId,
        parkName: widget.parkName,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );

      if (checkIn != null) {
        setState(() {
          _activeCheckIn = checkIn;
        });
        
        _showSuccessSnackBar('Woof! I\'m checked in at ${widget.parkName}! 🐕');
        widget.onCheckInSuccess?.call();
      } else {
        _showErrorSnackBar('Failed to check in. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await CheckInService.checkOut();

      if (success) {
        setState(() {
          _activeCheckIn = null;
        });
        
        _showSuccessSnackBar('Checked out successfully! See you next time! 🐾');
        widget.onCheckOutSuccess?.call();
      } else {
        _showErrorSnackBar('Failed to check out. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    // If user has an active check-in at a different park
    if (_activeCheckIn != null && _activeCheckIn!.parkId != widget.parkId) {
      return _buildDifferentParkCheckIn();
    }

    // If user has an active check-in at this park
    if (_activeCheckIn != null && _activeCheckIn!.parkId == widget.parkId) {
      return _buildCheckOutButton();
    }

    // Default check-in button
    return _buildCheckInButton();
  }

  Widget _buildCheckInButton() {
    if (widget.isFloating) {
      return FloatingActionButton.extended(
        onPressed: _isLoading ? null : _handleCheckIn,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.pets),
        label: Text(_isLoading ? 'Checking in...' : 'Check In Here'),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleCheckIn,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.pets),
          label: Text(_isLoading ? 'Checking in...' : 'Check In Here'),
        ),
      );
    }
  }

  Widget _buildCheckOutButton() {
    if (widget.isFloating) {
      return FloatingActionButton.extended(
        onPressed: _isLoading ? null : _handleCheckOut,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.exit_to_app),
        label: Text(_isLoading ? 'Checking out...' : 'Check Out'),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleCheckOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.exit_to_app),
          label: Text(_isLoading ? 'Checking out...' : 'Check Out'),
        ),
      );
    }
  }

  Widget _buildDifferentParkCheckIn() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'I\'m currently checked in at ${_activeCheckIn!.parkName}',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleCheckOut,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'Check Out',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckInStatusBanner extends StatefulWidget {
  const CheckInStatusBanner({super.key});

  @override
  State<CheckInStatusBanner> createState() => _CheckInStatusBannerState();
}

class _CheckInStatusBannerState extends State<CheckInStatusBanner> {
  CheckIn? _activeCheckIn;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveCheckIn();
  }

  Future<void> _loadActiveCheckIn() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final checkIn = await CheckInService.getActiveCheckIn(user.id);
      if (mounted) {
        setState(() {
          _activeCheckIn = checkIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading active check-in: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_activeCheckIn == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pets,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently at ${_activeCheckIn!.parkName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Checked in ${_activeCheckIn!.formattedCheckInTime}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await CheckInService.checkOut();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checked out successfully! 🐾'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadActiveCheckIn();
              }
            },
            child: Text(
              'Check Out',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
