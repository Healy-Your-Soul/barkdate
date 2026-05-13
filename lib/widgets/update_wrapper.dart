import 'package:flutter/material.dart';
import 'package:barkdate/services/update_service.dart';
import 'package:barkdate/design_system/app_colors.dart';

/// A wrapper widget that checks for required updates and shows a blocking
/// or non-blocking UI to the user.
class UpdateWrapper extends StatefulWidget {
  final Widget child;

  const UpdateWrapper({super.key, required this.child});

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  bool _isUpdateRequired = false;

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
      final theme = Theme.of(context);
      const backgroundColor = AppColors.lightBackground;
      const textColor = AppColors.lightTextPrimary;
      const subTextColor = AppColors.lightTextSecondary;

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: Stack(
            children: [
              // 1. Background Gradient (Subtle)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentOrange.withValues(alpha: 0.1),
                      backgroundColor,
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
                    color: AppColors.accentOrange.withValues(alpha: 0.1),
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
                                color: AppColors.accentOrange
                                    .withValues(alpha: 0.2),
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
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle / Message
                        Text(
                          UpdateService().updateMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: subTextColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Update Button
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: AppColors.warmGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentOrange
                                    .withValues(alpha: 0.3),
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
