import 'dart:typed_data';
import 'package:flutter/material.dart'; // For ImageProvider

/// Cross-platform selected image container.
/// Stores raw bytes and optional metadata so it works on Web, iOS, Android.
class SelectedImage {
  final Uint8List bytes;
  final String? fileName;
  final String? mimeType;

  const SelectedImage({
    required this.bytes,
    this.fileName,
    this.mimeType,
  });

  // Helper to get image data for display
  ImageProvider? get imageProvider {
    return MemoryImage(bytes);
  }

  // Helper to get image data for upload
  dynamic get uploadData {
    return bytes;
  }
}


