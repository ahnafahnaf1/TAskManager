import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'db_service.dart';

class VoiceNotePlayerService {
  VoiceNotePlayerService._() {
    _init();
  }
  static final VoiceNotePlayerService instance = VoiceNotePlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<String?> currentlyPlayingPath = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> currentPosition = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> totalDuration = ValueNotifier<Duration>(Duration.zero);

  void _init() {
    _player.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        currentlyPlayingPath.value = null;
        currentPosition.value = Duration.zero;
      }
    });

    _player.onDurationChanged.listen((d) {
      totalDuration.value = d;
    });

    _player.onPositionChanged.listen((p) {
      currentPosition.value = p;
    });
  }

  /// Toggle play / pause for a specific voice note file
  Future<void> togglePlay(String filePath) async {
    try {
      if (currentlyPlayingPath.value == filePath && isPlaying.value) {
        await _player.pause();
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          debugPrint('[VoiceNotePlayerService] File does not exist: $filePath');
          return;
        }
        currentlyPlayingPath.value = filePath;
        await _player.stop();
        await _player.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      debugPrint('[VoiceNotePlayerService] togglePlay error: $e');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      await _player.stop();
      currentlyPlayingPath.value = null;
      isPlaying.value = false;
    } catch (_) {}
  }

  /// Play voice note for alarm if enabled by user preference
  Future<void> playIfEnabledForAlarm(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final enabled = await DBService.instance.getSetting(
        'play_voice_note_on_alarm',
        defaultValue: 'true',
      );
      if (enabled == 'false') return;

      final file = File(filePath);
      if (await file.exists()) {
        await stop();
        currentlyPlayingPath.value = filePath;
        await _player.play(DeviceFileSource(filePath));
        debugPrint('[VoiceNotePlayerService] Playing voice note on alarm: $filePath');
      }
    } catch (e) {
      debugPrint('[VoiceNotePlayerService] playIfEnabledForAlarm error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
