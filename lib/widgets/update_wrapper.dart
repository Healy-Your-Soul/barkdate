import 'package:flutter/material.dart';
import 'package:barkdate/services/update_service.dart';

/// A wrapper widget that checks for required updates and shows a blocking
/// or non-blocking UI to the user.
class UpdateWrapper extends StatefulWidget {
  final Widget child;

  const UpdateWrapper({super.key, required this.child});

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  bool _isUpdateRequired = true;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  void _checkUpdate() {
    final updateService = UpdateService();
    if (updateService.isUpdateRequired()) {
      setState(() {
        _isUpdateRequired = true;
      });
    } else if (updateService.isUpdateAvailable()) {
      // Show a snackbar or non-blocking prompt for minor updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUpdateSnackBar();
      });
    }
  }

  void _showUpdateSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(UpdateService().updateMessage),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'UPDATE',
          onPressed: () => UpdateService().launchUpdateUrl(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isUpdateRequired) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        home: Scaffold(
          body: Stack(
            children: [
              // 1. Background Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFED924D).withValues(alpha: 0.1), // Primary low opacity
                      const Color(0xFFFF8076).withValues(alpha: 0.05), // Secondary low opacity
                      Colors.white,
                    ],
                  ),
                ),
              ),

              // 2. Decorative circles for depth
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFED924D).withValues(alpha: 0.1),
                  ),
                ),
              ),

              // 3. Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Icon
                        Container(
                          height: 160,
                          width: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFED924D).withValues(alpha: 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Title
                        Text(
                          'Paws for an Update!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2D2D2D),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle / Message
                        Text(
                          UpdateService().updateMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: const Color(0xFF717171),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Update Button
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFED924D), Color(0xFFFF8076)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFED924D).withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => UpdateService().launchUpdateUrl(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Update Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Secondary Info
                        Text(
                          'Keep your adventure going!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFED924D).withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
