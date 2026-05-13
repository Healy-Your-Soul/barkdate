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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        home: Scaffold(
          body: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.system_update_alt,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Update Required',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    UpdateService().updateMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => UpdateService().launchUpdateUrl(),
                    icon: const Icon(Icons.download),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
