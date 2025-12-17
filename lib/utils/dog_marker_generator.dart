import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Utility class for creating custom dog photo markers with colored borders
class DogMarkerGenerator {
  /// Cache of generated markers to avoid re-creating them
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Create a circular dog photo marker with a colored border
  /// 
  /// [imageUrl] - URL of the dog photo
  /// [borderColor] - Color of the border (based on freshness: green/orange/red)
  /// [size] - Size of the marker in pixels (default 80)
  /// [borderWidth] - Width of the colored border (default 4)
  static Future<BitmapDescriptor> createDogMarker({
    required String? imageUrl,
    required Color borderColor,
    int size = 80,
    double borderWidth = 4,
  }) async {
    // Create a cache key
    final cacheKey = '${imageUrl ?? 'default'}_${borderColor.value}_$size';
    
    // Return cached version if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Load the image from network
      ui.Image? dogImage;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        dogImage = await _loadNetworkImage(imageUrl);
      }
      
      // Create the marker image
      final markerBytes = await _createCircularMarker(
        dogImage: dogImage,
        borderColor: borderColor,
        size: size,
        borderWidth: borderWidth,
      );
      
      final descriptor = BitmapDescriptor.bytes(markerBytes);
      _cache[cacheKey] = descriptor;
      return descriptor;
    } catch (e) {
      debugPrint('Error creating dog marker: $e');
      // Return a default colored marker on error
      return BitmapDescriptor.defaultMarkerWithHue(
        _colorToHue(borderColor),
      );
    }
  }

  /// Load an image from a network URL
  static Future<ui.Image?> _loadNetworkImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );
      
      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    } catch (e) {
      debugPrint('Error loading network image: $e');
    }
    return null;
  }

  /// Create a circular marker with optional dog image and colored border
  static Future<Uint8List> _createCircularMarker({
    ui.Image? dogImage,
    required Color borderColor,
    required int size,
    required double borderWidth,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    
    // Draw shadow
    paint
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(2, 2), radius - 2, paint);
    
    // Reset paint
    paint.maskFilter = null;
    
    // Draw border (colored ring)
    paint.color = borderColor;
    canvas.drawCircle(center, radius - 2, paint);
    
    // Draw white ring (inner border)
    paint.color = Colors.white;
    final innerRadius = radius - borderWidth - 2;
    canvas.drawCircle(center, innerRadius, paint);
    
    if (dogImage != null) {
      // Clip and draw the dog image
      canvas.save();
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: innerRadius - 2));
      canvas.clipPath(clipPath);
      
      // Scale and center the image
      final imageSize = dogImage.width > dogImage.height 
          ? dogImage.height.toDouble() 
          : dogImage.width.toDouble();
      final srcRect = Rect.fromCenter(
        center: Offset(dogImage.width / 2, dogImage.height / 2),
        width: imageSize,
        height: imageSize,
      );
      final dstRect = Rect.fromCircle(center: center, radius: innerRadius - 2);
      
      canvas.drawImageRect(dogImage, srcRect, dstRect, Paint());
      canvas.restore();
    } else {
      // Draw a dog icon placeholder
      paint.color = Colors.grey[300]!;
      canvas.drawCircle(center, innerRadius - 2, paint);
      
      // Draw paw print icon
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🐕',
          style: TextStyle(fontSize: size * 0.4),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }
    
    // Convert to bytes
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  /// Convert a Color to BitmapDescriptor hue (fallback)
  static double _colorToHue(Color color) {
    if (color == Colors.green || color.value == Colors.green.value) {
      return BitmapDescriptor.hueGreen;
    } else if (color == Colors.orange || color.value == Colors.orange.value) {
      return BitmapDescriptor.hueOrange;
    } else if (color == Colors.red || color.value == Colors.red.value) {
      return BitmapDescriptor.hueRed;
    }
    return BitmapDescriptor.hueAzure;
  }

  /// Get border color based on how recently location was updated
  static Color getBorderColorForAge(double hoursAgo) {
    if (hoursAgo < 1.0) {
      return Colors.green; // 0-1 hour: green (active)
    } else if (hoursAgo < 3.0) {
      return Colors.orange; // 1-3 hours: orange (recent)
    } else {
      return Colors.red; // 3-4 hours: red (stale)
    }
  }

  /// Clear the marker cache (useful when settings change)
  static void clearCache() {
    _cache.clear();
  }
  
  /// Create a custom place marker with category-specific color and icon
  /// 
  /// [category] - Place category (park, cafe, store, vet, etc.)
  /// [size] - Size of the marker in pixels (default 40)
  static Future<BitmapDescriptor> createPlaceMarker({
    required String category,
    int size = 40,
  }) async {
    // Create a cache key
    final cacheKey = 'place_${category}_$size';
    
    // Return cached version if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Get color and icon based on category
      Color markerColor;
      String icon;
      
      switch (category.toLowerCase()) {
        case 'park':
        case 'dog_park':
          markerColor = Colors.green;
          icon = 'P';  // Park
          break;
        case 'cafe':
        case 'restaurant':
          markerColor = Colors.orange;
          icon = 'C';  // Cafe
          break;
        case 'store':
        case 'pet_store':
        case 'petstore':
          markerColor = Colors.blue;
          icon = 'S';  // Store
          break;
        case 'veterinary':
        case 'vet':
          markerColor = Colors.red;
          icon = 'V';  // Vet
          break;
        default:
          markerColor = Colors.purple;
          icon = '•';  // Other
      }
      
      final markerBytes = await _createPlaceMarkerImage(
        color: markerColor,
        icon: icon,
        size: size,
      );
      
      final descriptor = BitmapDescriptor.bytes(markerBytes);
      _cache[cacheKey] = descriptor;
      return descriptor;
    } catch (e) {
      debugPrint('Error creating place marker: $e');
      // Return a default marker on error
      return BitmapDescriptor.defaultMarker;
    }
  }
  
  /// Create the place marker image with colored background and icon
  static Future<Uint8List> _createPlaceMarkerImage({
    required Color color,
    required String icon,
    required int size,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    
    // Draw shadow
    paint
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + const Offset(1, 1), radius - 2, paint);
    
    // Reset paint
    paint.maskFilter = null;
    
    // Draw colored circle
    paint.color = color;
    canvas.drawCircle(center, radius - 2, paint);
    
    // Draw white border
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 3, paint);
    
    // Draw white letter icon in center (more reliable than emojis)
    final textPainter = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
    
    // Convert to bytes
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
}
