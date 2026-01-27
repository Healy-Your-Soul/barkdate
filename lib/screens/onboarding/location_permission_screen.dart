import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/screens/auth/sign_in_screen.dart';
import 'package:barkdate/services/location_service.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> {
  bool _locationEnabled = false;
  bool _notificationsEnabled = false;

  Future<void> _navigateNext() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) {
      // Not signed in → go to Sign In
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
      return;
    }

    // Signed in → proceed to profile setup with userId
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProfileScreen(
          userId: user.id,
          userName: user.userMetadata?['name'],
          userEmail: user.email,
          locationEnabled: _locationEnabled,
          editMode: EditMode.createProfile, // Use createProfile mode to navigate to /home after
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission() async {
    final user = SupabaseConfig.auth.currentUser;
    if (user == null) return;

    // Request permission
    final granted = await LocationService.requestPermission();
    
    if (granted) {
      // Sync location to database
      final synced = await LocationService.syncLocation(user.id);
      setState(() => _locationEnabled = synced);
      if (synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location enabled!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      // Request notification permission using Firebase Messaging directly
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                      settings.authorizationStatus == AuthorizationStatus.provisional;
      
      setState(() => _notificationsEnabled = granted);
      
      if (granted && mounted) {
        // Get and save FCM token
        final user = SupabaseConfig.auth.currentUser;
        if (user != null) {
          final token = await messaging.getToken();
          if (token != null) {
            await SupabaseConfig.client
                .from('users')
                .update({'fcm_token': token})
                .eq('id', user.id);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications enabled!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  Future<void> _enableAllPermissions() async {
    await _requestLocationPermission();
    await _requestNotificationPermission();
    await _navigateNext();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Illustration
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.pets,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    // Location pin
                    Positioned(
                      top: 30,
                      right: 40,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _locationEnabled ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, size: 20, color: Colors.white),
                      ),
                    ),
                    // Notification bell
                    Positioned(
                      top: 30,
                      left: 40,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _notificationsEnabled ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Set Up Permissions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Description
              Text(
                'Enable these for the best experience',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Permission toggles
              _buildPermissionTile(
                context,
                icon: Icons.location_on,
                title: 'Location',
                subtitle: 'Find nearby dogs and parks',
                enabled: _locationEnabled,
                onTap: _requestLocationPermission,
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Get alerts for barks and messages',
                enabled: _notificationsEnabled,
                onTap: _requestNotificationPermission,
              ),
              
              const Spacer(),
              
              // Enable All button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enableAllPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled 
              ? Colors.green.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? Colors.green : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enabled ? Colors.green : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? Icons.check_circle : Icons.circle_outlined,
              color: enabled ? Colors.green : Colors.grey,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
