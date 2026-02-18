import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:barkdate/supabase/supabase_config.dart';
import 'package:barkdate/models/featured_park.dart';
import 'package:barkdate/services/checkin_service.dart';

/// Service for handling QR code-based check-ins at parks
class QrCheckInService {
  static final _client = SupabaseConfig.client;
  static const String _baseUrl = 'https://barkdate.app';

  /// Generate a unique check-in code for a park
  static String generateCheckInCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing chars
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate or get the QR code URL for a park
  /// Returns the URL that should be encoded in the QR code
  static String getQrCodeData(String parkId, String checkInCode) {
    return '$_baseUrl/checkin?park=$parkId&code=$checkInCode';
  }

  /// Generate a check-in code for a park and save it to the database
  static Future<String?> generateAndSaveCheckInCode(String parkId) async {
    try {
      final code = generateCheckInCode();

      await _client
          .from('featured_parks')
          .update({'qr_check_in_code': code}).eq('id', parkId);

      debugPrint('✅ Generated QR check-in code: $code for park: $parkId');
      return code;
    } catch (e) {
      debugPrint('❌ Failed to generate check-in code: $e');
      return null;
    }
  }

  /// Validate a QR check-in code and return the park if valid
  static Future<FeaturedPark?> validateCheckInCode({
    required String parkId,
    required String code,
  }) async {
    try {
      final data = await _client
          .from('featured_parks')
          .select('*')
          .eq('id', parkId)
          .eq('qr_check_in_code', code)
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) {
        debugPrint('❌ Invalid QR code: park=$parkId, code=$code');
        return null;
      }

      debugPrint('✅ Valid QR code for park: ${data['name']}');
      return FeaturedPark.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error validating QR code: $e');
      return null;
    }
  }

  /// Process a QR code scan and check in the user
  static Future<QrCheckInResult> processQrCheckIn({
    required String qrData,
  }) async {
    try {
      // Parse the QR data URL
      Uri? uri;
      try {
        uri = Uri.parse(qrData);
      } catch (_) {
        return QrCheckInResult.error('Invalid QR code format');
      }

      final parkId = uri.queryParameters['park'];
      final code = uri.queryParameters['code'];

      if (parkId == null || code == null) {
        return QrCheckInResult.error('QR code missing required data');
      }

      // Validate the code
      final park = await validateCheckInCode(parkId: parkId, code: code);
      if (park == null) {
        return QrCheckInResult.error('Invalid or expired QR code');
      }

      // Check in the user
      final checkIn = await CheckInService.checkInAtPark(
        parkId: parkId,
        parkName: park.name,
        latitude: park.latitude,
        longitude: park.longitude,
      );

      if (checkIn == null) {
        return QrCheckInResult.error(
            'Failed to check in. You may already be checked in elsewhere.');
      }

      return QrCheckInResult.success(park);
    } catch (e) {
      debugPrint('❌ Error processing QR check-in: $e');
      return QrCheckInResult.error('An unexpected error occurred');
    }
  }

  /// Get the deep link URL for opening the app directly
  static String getDeepLinkUrl(String parkId, String checkInCode) {
    return 'barkdate://checkin?park=$parkId&code=$checkInCode';
  }

  /// Get the web fallback URL for users without the app
  static String getWebFallbackUrl(String parkId, String checkInCode) {
    return '$_baseUrl/checkin?park=$parkId&code=$checkInCode';
  }
}

/// Result of a QR check-in attempt
class QrCheckInResult {
  final bool success;
  final FeaturedPark? park;
  final String? errorMessage;

  QrCheckInResult._({
    required this.success,
    this.park,
    this.errorMessage,
  });

  factory QrCheckInResult.success(FeaturedPark park) {
    return QrCheckInResult._(success: true, park: park);
  }

  factory QrCheckInResult.error(String message) {
    return QrCheckInResult._(success: false, errorMessage: message);
  }
}
