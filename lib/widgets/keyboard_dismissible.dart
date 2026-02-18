import 'package:flutter/material.dart';

/// A wrapper widget that dismisses the keyboard when tapping outside text fields.
///
/// Wrap any screen or widget hierarchy with this to enable tap-to-dismiss keyboard behavior.
///
/// Usage:
/// ```dart
/// KeyboardDismissible(
///   child: Scaffold(
///     body: YourContent(),
///   ),
/// )
/// ```
class KeyboardDismissible extends StatelessWidget {
  final Widget child;

  /// Whether to use translucent hit test behavior (allows child gestures to also fire)
  final bool translucent;

  const KeyboardDismissible({
    super.key,
    required this.child,
    this.translucent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior:
          translucent ? HitTestBehavior.translucent : HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// Extension method for easy keyboard dismissal
extension KeyboardDismiss on BuildContext {
  /// Dismiss the keyboard
  void dismissKeyboard() {
    FocusScope.of(this).unfocus();
  }
}

/// A scaffold wrapper that automatically dismisses keyboard on tap
/// and handles keyboard-aware scrolling for input fields.
class KeyboardAwareScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const KeyboardAwareScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: true,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }
}

/// Padding widget that adds bottom padding for keyboard
class KeyboardPadding extends StatelessWidget {
  final Widget child;
  final double extraPadding;

  const KeyboardPadding({
    super.key,
    required this.child,
    this.extraPadding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + extraPadding,
      ),
      child: child,
    );
  }
}
