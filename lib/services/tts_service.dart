import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48); // Natural, clear speaking speed
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      debugPrint('[TtsService] Init error: $e');
    }
  }

  /// Speaks text asynchronously without awaiting completion
  Future<void> speak(String text) async {
    try {
      await _init();
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Speak error: $e');
    }
  }

  /// Speaks text and awaits until playback finishes (or times out)
  Future<void> speakAndWait(String text, {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      await _init();
      await _flutterTts.stop();

      final completer = Completer<void>();

      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      _flutterTts.setErrorHandler((dynamic err) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await _flutterTts.speak(text);

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('[TtsService] Speech timeout reached');
        },
      );
    } catch (e) {
      debugPrint('[TtsService] speakAndWait error: $e');
    }
  }

  /// Stops current speech immediately
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
