import 'package:flutter/material.dart';
import 'package:barkdate/screens/onboarding/create_profile_screen.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/screens/auth/sign_in_screen.dart';
import 'package:barkdate/services/settings_service.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationPermissionScreen extends StatelessWidget {
  final String? userId;
  final String? userName;
  final String? userEmail;

  const LocationPermissionScreen({
    super.key,
    this.userId,
    this.userName,
    this.userEmail,
  });

  Future<void> _navigateNext(BuildContext context, {required bool locationEnabled}) async {
    // Save location preference to settings
    await SettingsService().setLocationEnabled(locationEnabled);
    
    // Optional: Save location preference to user profile in Supabase
    final user = SupabaseConfig.auth.currentUser;
    if (user != null) {
      try {
        // You can uncomment this if you want to store location preference in database
        // await Supabase.instance.client
        //     .from('users')
        //     .update({'location_enabled': locationEnabled})
        //     .eq('id', user.id);
      } catch (e) {
        // Non-critical error, continue with local storage
        debugPrint('Could not save location preference to database: $e');
      }
    }
    
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
          userId: userId ?? user.id,
          userName: userName ?? user.userMetadata?['full_name'] ?? user.email?.split('@')[0],
          userEmail: userEmail ?? user.email,
          locationEnabled: locationEnabled,
          editMode: EditMode.createProfile,
        ),
      ),
    );
  }

  Future<void> _requestLocationPermission(BuildContext context) async {
    try {
      // Request actual location permissions
      Location location = Location();
      
      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          // User denied location service, continue with disabled location
          await _navigateNext(context, locationEnabled: false);
          return;
        }
      }

      // Check location permissions
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          // User denied location permission, continue with disabled location
          await _navigateNext(context, locationEnabled: false);
          return;
        }
      }

      // Location permission granted, save to settings and continue
      await _navigateNext(context, locationEnabled: true);
    } catch (e) {
      // Error requesting location, continue with disabled location
      debugPrint('Error requesting location permission: $e');
      await _navigateNext(context, locationEnabled: false);
    }
  }

  void _skipLocationPermission(BuildContext context) {
    // Navigate with limited features flag
    _navigateNext(context, locationEnabled: false);
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
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Park background
                    Icon(
                      Icons.park,
                      size: 120,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    // Dog icon
                    Positioned(
                      bottom: 60,
                      child: Icon(
                        Icons.pets,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    // Location pin
                    Positioned(
                      top: 50,
                      right: 70,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              
              // Title
              Text(
                'Enable Location Services',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'To find nearby dogs and schedule playdates, we need access to your location. This helps us show you dogs in your area and plan meetups.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Benefits list
              Column(
                children: [
                  _buildBenefitItem(
                    context,
                    Icons.search,
                    'Find dogs within your preferred distance',
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitItem(
                    context,
                    Icons.map,
                    'Discover dog-friendly parks nearby',
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitItem(
                    context,
                    Icons.group_add,
                    'Connect with local dog owners',
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Enable Location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _requestLocationPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Enable Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Maybe Later button
              TextButton(
                onPressed: () => _skipLocationPermission(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
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
