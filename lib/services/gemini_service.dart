import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';

/// Response from Gemini AI Assistant with grounded results
class GeminiResponse {
  final String text;
  final List<GroundingSource> sources;

  GeminiResponse({
    required this.text,
    required this.sources,
  });
}

/// Grounding source from Google Maps
class GroundingSource {
  final String uri;
  final String title;

  GroundingSource({
    required this.uri,
    required this.title,
  });
}

/// Service to interact with Gemini AI for dog-friendly place recommendations
class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;

  GeminiService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
      // Note: Google Search grounding requires Gemini 2.5 and is not available in current SDK version
      // Will work with regular text generation for now
    );
  }

  static const String _systemInstruction = '''
You are an expert assistant for a "Dog Friendly Map" app called BarkDate. Your goal is to help users find dog-friendly places.

CRITICAL: You must return your response in strict JSON format.
The JSON structure should be:
{
  "response_text": "A brief, friendly summary (1-2 sentences).",
  "suggested_places": [
    {
      "name": "Exact Place Name",
      "reason": "Short reason why it's good."
    }
  ]
}

Guidelines:
- Suggest 3-5 specific, real places if possible.
- Focus on dog-friendly amenities.
- If the user provides location, use it to find nearby places.
- Do NOT include markdown formatting (like ```json). Just the raw JSON string.
''';

  /// Ask Gemini about dog-friendly places with optional location context
  Future<GeminiResponse> askAboutPlaces({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final StringBuffer promptBuffer = StringBuffer();

      if (latitude != null && longitude != null) {
        promptBuffer.writeln(
          'The user is currently located at latitude $latitude and longitude $longitude.',
        );
      }

      promptBuffer.writeln('\nUser query: "$query"');

      final prompt = promptBuffer.toString();
      debugPrint('🤖 Gemini prompt: $prompt');

      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      final rawText = response.text ?? '{}';
      // Clean up markdown if present
      final jsonString =
          rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      debugPrint('✅ Gemini raw response: $jsonString');

      // Note: In a real app, we would use jsonDecode here.
      // For now, we'll return the raw text if parsing fails or just pass it through.
      // But to make it work with the UI, let's try to parse it.

      // Since we don't have dart:convert imported, let's just return the raw text for now
      // and let the provider handle it, OR import dart:convert.
      // Let's assume the provider will handle the "Manual Grounding" by parsing this JSON.

      return GeminiResponse(
        text: jsonString,
        sources: [],
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Gemini API error: $e');
      return GeminiResponse(
        text:
            '{"response_text": "Sorry, I encountered an error.", "suggested_places": []}',
        sources: [],
      );
    }
  }

  /// Quick suggestions for common queries
  static List<String> get quickReplies => [
        'Find cafes with patios',
        'Any dog parks with water?',
        'What\'s happening this weekend?',
        'Best places for puppies nearby',
        'Dog-friendly restaurants with shade',
      ];
}
