// Test file to verify PlaydatesScreen import
import 'package:flutter/material.dart';
import 'lib/screens/playdates_screen.dart';

void main() {
  // Test if we can reference the PlaydatesScreen class
  var screen = const PlaydatesScreen();
  print('PlaydatesScreen import works: ${screen.runtimeType}');
}
