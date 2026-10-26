import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceRecognitionService {
  VoiceRecognitionService._();
  static final VoiceRecognitionService instance = VoiceRecognitionService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String? _selectedLocaleId;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  /// Initialize speech recognizer and request microphone access
  Future<bool> initialize() async {
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('[VoiceRecognitionService] onError: ${val.errorMsg}'),
        onStatus: (val) => debugPrint('[VoiceRecognitionService] onStatus: $val'),
      );

      if (_isInitialized) {
        // Detect if Tamil locale is installed on the device (ta_IN or ta_LK)
        final locales = await _speech.locales();
        for (final loc in locales) {
          if (loc.localeId.toLowerCase().startsWith('ta')) {
            _selectedLocaleId = loc.localeId;
            break;
          }
        }
        // Fallback to default system locale if Tamil speech pack is not installed
        _selectedLocaleId ??= (await _speech.systemLocale())?.localeId ?? 'en_US';
        debugPrint('[VoiceRecognitionService] Using locale: $_selectedLocaleId');
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceRecognitionService] Init error: $e');
      return false;
    }
  }

  /// Start listening to voice input
  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        throw Exception('Microphone permission or speech recognition unavailable');
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: _selectedLocaleId,
      ),
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Cancel listening
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
