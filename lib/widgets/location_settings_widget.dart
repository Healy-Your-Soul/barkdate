import 'package:barkdate/services/location_service.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:flutter/material.dart';

class LocationSettingsWidget extends StatefulWidget {
  final VoidCallback? onLocationChanged;

  const LocationSettingsWidget({
    super.key,
    this.onLocationChanged,
  });

  @override
  State<LocationSettingsWidget> createState() => _LocationSettingsWidgetState();
}

class _LocationSettingsWidgetState extends State<LocationSettingsWidget> {
  bool _isEnabled = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  LocationPermissionInfo? _permissionInfo;
  String? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadLocationStatus();
  }

  Future<void> _loadLocationStatus() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseConfig.auth.currentUser;
      if (user == null) return;

      // Check if location is enabled in database
      final enabled = await LocationService.isLocationEnabled(user.id);
      
      // Check permission status
      final permissionInfo = await LocationService.checkPermissionStatus();
      
      // Get current location if available
      String? locationText;
      if (enabled) {
        final location = await LocationService.getUserLocation(user.id);
        if (location != null) {
          locationText = '${location['latitude']!.toStringAsFixed(4)}, ${location['longitude']!.toStringAsFixed(4)}';
        }
      }

      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _permissionInfo = permissionInfo;
          _currentLocation = locationText;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading location status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLocation(bool value) async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    if (value) {
      // User wants to enable location
      await _enableLocation();
    } else {
      // User wants to disable location
      await _disableLocation();
    }
  }

  Future<void> _enableLocation() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    setState(() => _isSyncing = true);

    try {
      // Check permission first
      final permissionInfo = await LocationService.checkPermissionStatus();
      
      if (permissionInfo.status == LocationStatus.permissionDenied) {
        // Request permission
        final granted = await LocationService.requestPermission();
        if (!granted) {
          if (mounted) {
            _showError('Location permission is required to find nearby dogs and events.');
          }
          setState(() => _isSyncing = false);
          return;
        }
      } else if (permissionInfo.status == LocationStatus.permissionDeniedForever) {
        // Need to open settings
        if (mounted) {
          final shouldOpen = await _showSettingsDialog(
            'Location Permission Required',
            'Please enable location permission in your device settings to find nearby dogs and events.',
          );
          if (shouldOpen) {
            await LocationService.openAppSettings();
          }
        }
        setState(() => _isSyncing = false);
        return;
      } else if (permissionInfo.status == LocationStatus.serviceDisabled) {
        // Need to enable location service
        if (mounted) {
          final shouldOpen = await _showSettingsDialog(
            'Location Service Disabled',
            'Please enable location services on your device to use this feature.',
          );
          if (shouldOpen) {
            await LocationService.openLocationSettings();
          }
        }
        setState(() => _isSyncing = false);
        return;
      }

      // Get current location and save it
      final success = await LocationService.syncLocation(user.id);
      
      if (success) {
        await _loadLocationStatus();
        widget.onLocationChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location enabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          _showError('Failed to get your location. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('Error enabling location: $e');
      if (mounted) {
        _showError('An error occurred while enabling location.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _disableLocation() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Location?'),
        content: const Text(
          'Disabling location will:\n\n'
          '• Hide you from nearby dog searches\n'
          '• Prevent you from finding nearby dogs\n'
          '• Limit event discovery\n\n'
          'You can re-enable it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);

    try {
      await LocationService.disableLocation(user.id);
      await _loadLocationStatus();
      widget.onLocationChanged?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disabling location: $e');
      if (mounted) {
        _showError('Failed to disable location. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _refreshLocation() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    setState(() => _isSyncing = true);

    try {
      final success = await LocationService.syncLocation(user.id);
      
      if (success) {
        await _loadLocationStatus();
        widget.onLocationChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          _showError('Failed to update location. Please check your permissions.');
        }
      }
    } catch (e) {
      debugPrint('Error refreshing location: $e');
      if (mounted) {
        _showError('An error occurred while updating location.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<bool> _showSettingsDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEnabled
                            ? 'Your location is being shared'
                            : 'Location sharing is disabled',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _isEnabled,
                    onChanged: _toggleLocation,
                  ),
              ],
            ),
            
            if (_permissionInfo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor().withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _permissionInfo!.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_isEnabled && _currentLocation != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.pin_drop, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: $_currentLocation',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSyncing ? null : _refreshLocation,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ],
            
            if (!_isEnabled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why enable location?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Find nearby dogs for playdates\n'
                      '• Discover local dog events\n'
                      '• Connect with dog owners in your area\n'
                      '• Get personalized recommendations',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_permissionInfo == null) return Colors.grey;
    
    switch (_permissionInfo!.status) {
      case LocationStatus.enabled:
        return Colors.green;
      case LocationStatus.disabled:
      case LocationStatus.serviceDisabled:
        return Colors.orange;
      case LocationStatus.permissionDenied:
      case LocationStatus.permissionDeniedForever:
        return Colors.red;
      case LocationStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (_permissionInfo == null) return Icons.help_outline;
    
    switch (_permissionInfo!.status) {
      case LocationStatus.enabled:
        return Icons.check_circle;
      case LocationStatus.disabled:
      case LocationStatus.serviceDisabled:
        return Icons.warning;
      case LocationStatus.permissionDenied:
      case LocationStatus.permissionDeniedForever:
        return Icons.error;
      case LocationStatus.unknown:
        return Icons.help_outline;
    }
  }
}
