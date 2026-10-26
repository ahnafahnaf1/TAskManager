import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  static const String _prefKeyApiKey = 'gemini_api_key';

  String? _cachedApiKey;
  String? _activeWorkingModel;

  /// Ordered list of active high-speed Flash models supporting multimodal audio
  static const List<String> _recommendedModels = [
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-3-flash-preview',
    'gemini-flash-latest',
  ];

  /// Load cached or stored API key
  Future<String?> getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedApiKey = prefs.getString(_prefKeyApiKey)?.trim();
    return _cachedApiKey;
  }

  /// Save new API key
  Future<void> saveApiKey(String key) async {
    final cleanKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyApiKey, cleanKey);
    _cachedApiKey = cleanKey;
    _activeWorkingModel = null;
  }

  /// Remove API key
  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyApiKey);
    _cachedApiKey = null;
    _activeWorkingModel = null;
  }

  /// Validate API key with minimal request
  Future<bool> validateApiKey(String key) async {
    try {
      final cleanKey = key.trim();
      if (cleanKey.isEmpty) return false;

      for (final model in _recommendedModels) {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'ping'}
                    ]
                  }
                ]
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _activeWorkingModel = model;
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends multimodal parts to Gemini using recommended models with auto-fallback
  Future<http.Response> _sendContentsWithFallback({
    required String apiKey,
    required List<Map<String, dynamic>> contentsParts,
  }) async {
    final modelsToTry = {
      if (_activeWorkingModel != null) _activeWorkingModel!,
      ..._recommendedModels,
    }.toList();

    http.Response? lastResponse;

    for (final model in modelsToTry) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': contentsParts,
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'responseMimeType': 'application/json',
                }
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          _activeWorkingModel = model;
          debugPrint('[GeminiService] Successfully generated with model: $model');
          return response;
        }

        debugPrint('[GeminiService] Model $model returned status ${response.statusCode}');
        lastResponse = response;

        if (response.statusCode == 404 || response.statusCode == 503) {
          continue;
        }

        return response;
      } catch (e) {
        debugPrint('[GeminiService] Model $model request failed: $e');
      }
    }

    return lastResponse ??
        http.Response(
          jsonEncode({
            'error': {'message': 'Unable to connect to Gemini API. Please check internet connection.'}
          }),
          500,
        );
  }

  /// Parses voice audio bytes directly without client-side speech-to-text.
  /// Translates Tamil/Tanglish/English to an English task title and exact DateTime.
  Future<Map<String, dynamic>> parseVoiceAudio(
    Uint8List audioBytes, {
    String mimeType = 'audio/m4a',
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please add it in Settings.');
    }

    final now = DateTime.now();
    final todayFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final weekdayName = DateFormat('EEEE').format(now);

    final prompt = '''
You are an intelligent scheduling assistant for a personal task manager app.
Today is: $todayFormatted ($weekdayName). Current year: ${now.year}.

The user spoke a scheduling command in the attached audio recording (which may be in Tamil, Tanglish, or English).

TASK:
1. Listen carefully to the voice recording and transcribe what the user said into "originalSpeech".
2. Identify the task action/subject and translate it into a concise, professional English Title (e.g., "Interview", "Dentist Appointment", "Doctor Consultation", "Project Meeting").
3. Determine the intended target date and time.
   - If user says relative dates (e.g. "today", "naalaikku" / "tomorrow", "day after tomorrow", "next Monday"), calculate the exact target date relative to $todayFormatted.
   - If user specifies only date without time (e.g. "May 21-m thigathi interview"), schedule for 09:00:00 AM on that date, and set "timeAssumed": true.
   - If time is specified (e.g. "10:30 am", "5 manikku" / "5 o'clock"), set "timeAssumed": false.
   - If the calculated date/time is in the past, move it to the upcoming occurrence.
4. Return ONLY a single raw valid JSON object (no markdown, no extra explanation).

JSON FORMAT:
{
  "originalSpeech": "transcription of what user said",
  "title": "Interview",
  "scheduledTime": "YYYY-MM-DDTHH:mm:ss",
  "timeAssumed": true
}
''';

    final base64Audio = base64Encode(audioBytes);
    final parts = [
      {
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Audio,
        }
      },
      {
        'text': prompt,
      }
    ];

    final response = await _sendContentsWithFallback(
      apiKey: apiKey,
      contentsParts: parts,
    );

    return _processJsonResponse(response, now);
  }

  /// Parses voice command text as a fallback if text is provided
  Future<Map<String, dynamic>> parseVoiceCommand(String speechText) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is not set. Please add it in Settings.');
    }

    final now = DateTime.now();
    final todayFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final weekdayName = DateFormat('EEEE').format(now);

    final prompt = '''
You are an intelligent scheduling assistant for a personal task manager app.
Today is: $todayFormatted ($weekdayName). Current year: ${now.year}.

The user spoke this voice command (which may be in Tamil, Tanglish, or English):
"$speechText"

TASK:
1. Identify the task action/subject and translate it into a concise, professional English Title (e.g., "Interview", "Dentist Appointment", "Project Presentation", "Client Call").
2. Determine the intended target date and time.
   - If user says relative dates (e.g. "today", "naalaikku" / "tomorrow", "day after tomorrow", "next Monday"), calculate the exact target date relative to $todayFormatted.
   - If user specifies only date without time (e.g. "May 21-m thigathi interview"), schedule for 09:00:00 AM on that date, and set "timeAssumed": true.
   - If time is specified (e.g. "10:30 am", "5 manikku" / "5 o'clock"), set "timeAssumed": false.
   - If the calculated date/time is in the past, move it to the upcoming occurrence.
3. Return ONLY a single raw valid JSON object (no markdown code blocks, no ```json formatting, no explanation).

JSON FORMAT:
{
  "originalSpeech": "$speechText",
  "title": "Interview",
  "scheduledTime": "YYYY-MM-DDTHH:mm:ss",
  "timeAssumed": true
}
''';

    final parts = [
      {'text': prompt}
    ];

    final response = await _sendContentsWithFallback(
      apiKey: apiKey,
      contentsParts: parts,
    );

    return _processJsonResponse(response, now);
  }

  Map<String, dynamic> _processJsonResponse(http.Response response, DateTime now) {
    if (response.statusCode != 200) {
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw Exception('Invalid Gemini API Key or permission denied.');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment and try again.');
      } else {
        try {
          final errBody = jsonDecode(response.body);
          final msg = errBody['error']?['message'] ?? response.body;
          throw Exception('Gemini error (${response.statusCode}): $msg');
        } catch (_) {
          throw Exception('Gemini error (${response.statusCode}): ${response.body}');
        }
      }
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response generated by Gemini.');
    }

    final contentParts = candidates[0]['content']?['parts'] as List?;
    if (contentParts == null || contentParts.isEmpty) {
      throw Exception('Empty content response from Gemini.');
    }

    String rawText = contentParts[0]['text'] as String? ?? '';
    rawText = rawText.trim();

    // Clean any accidental markdown code fences
    if (rawText.startsWith('```json')) {
      rawText = rawText.substring(7);
    } else if (rawText.startsWith('```')) {
      rawText = rawText.substring(3);
    }
    if (rawText.endsWith('```')) {
      rawText = rawText.substring(0, rawText.length - 3);
    }
    rawText = rawText.trim();

    final parsedJson = jsonDecode(rawText) as Map<String, dynamic>;
    final String title = parsedJson['title']?.toString().trim() ?? 'Scheduled Task';
    final String originalSpeech = parsedJson['originalSpeech']?.toString().trim() ?? '';
    final String timeStr = parsedJson['scheduledTime']?.toString() ?? '';
    final bool timeAssumed = parsedJson['timeAssumed'] == true;

    DateTime scheduledTime;
    try {
      scheduledTime = DateTime.parse(timeStr);
    } catch (_) {
      scheduledTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    if (scheduledTime.isBefore(now)) {
      if (scheduledTime.isBefore(now.add(const Duration(hours: -1)))) {
        scheduledTime = DateTime(
          scheduledTime.year + 1,
          scheduledTime.month,
          scheduledTime.day,
          scheduledTime.hour,
          scheduledTime.minute,
        );
      } else {
        scheduledTime = now.add(const Duration(hours: 1));
      }
    }

    return {
      'title': title,
      'originalSpeech': originalSpeech,
      'scheduledTime': scheduledTime,
      'timeAssumed': timeAssumed,
      'rawResponse': rawText,
    };
  }

  /// Evaluates short confirmation audio clip. Returns true for affirmative (yes/oom/aam/sari),
  /// false for negative (no/illai/vendaam/cancel), and null if unclear or silence.
  Future<bool?> evaluateVoiceConfirmation(Uint8List audioBytes) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final base64Audio = base64Encode(audioBytes);
    const prompt = '''
You are a voice intent classifier. Analyze this short audio clip of a user answering a confirmation question ("Do you want to schedule this task / meeting?").
Determine if the user said:
- YES / AFFIRMATIVE: words such as "yes", "yeah", "yep", "sure", "ok", "okay", "save", "schedule it", or Tamil/Tanglish words like "oom", "om", "aam", "aama", "sari", "seri", "pannu", "vai", "kandippa".
- NO / NEGATIVE: words such as "no", "nope", "cancel", "don't", "stop", or Tamil/Tanglish words like "illai", "illa", "vendaam", "vendam", "maattaen", "reject".
- UNCLEAR / SILENCE: background noise, silence, or unintelligible words.

Return strictly a JSON object:
{"confirmed": true}
or
{"confirmed": false}
or
{"confirmed": null}
''';

    final parts = [
      {
        'inlineData': {
          'mimeType': 'audio/mp4',
          'data': base64Audio,
        }
      },
      {'text': prompt}
    ];

    try {
      final response = await _sendContentsWithFallback(
        apiKey: apiKey,
        contentsParts: parts,
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final contentParts = candidates[0]['content']?['parts'] as List?;
      if (contentParts == null || contentParts.isEmpty) return null;

      String rawText = contentParts[0]['text'] as String? ?? '';
      rawText = rawText.trim();
      if (rawText.startsWith('```json')) rawText = rawText.substring(7);
      if (rawText.startsWith('```')) rawText = rawText.substring(3);
      if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
      rawText = rawText.trim();

      final parsed = jsonDecode(rawText) as Map<String, dynamic>;
      final val = parsed['confirmed'];
      if (val is bool) return val;
      return null;
    } catch (e) {
      debugPrint('[GeminiService] evaluateVoiceConfirmation error: $e');
      return null;
    }
  }
}
