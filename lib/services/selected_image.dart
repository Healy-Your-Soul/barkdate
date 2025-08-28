import 'dart:typed_data';

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
}


