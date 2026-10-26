import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordingResult {
  final Uint8List bytes;
  final String permanentFilePath;

  const VoiceRecordingResult({
    required this.bytes,
    required this.permanentFilePath,
  });
}

class AudioRecorderService {
  AudioRecorderService._();
  static final AudioRecorderService instance = AudioRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentFilePath;

  bool get isRecording => _isRecording;

  /// Check and request microphone permission
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[AudioRecorderService] Permission check error: $e');
      return false;
    }
  }

  /// Start recording audio into a local temporary file
  Future<bool> startRecording() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      final hasPerm = await hasPermission();
      if (!hasPerm) {
        debugPrint('[AudioRecorderService] Microphone permission denied');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${tempDir.path}/voice_task_$timestamp.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      await _recorder.start(config, path: _currentFilePath!);
      _isRecording = true;
      debugPrint('[AudioRecorderService] Recording started at: $_currentFilePath');
      return true;
    } catch (e) {
      debugPrint('[AudioRecorderService] startRecording error: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording, copy audio to permanent app storage for Voice Notes, and return bytes
  Future<VoiceRecordingResult?> stopRecordingAndSaveVoiceNote() async {
    try {
      if (!_isRecording && !(await _recorder.isRecording())) {
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;

      final filePath = path ?? _currentFilePath;
      if (filePath == null) return null;

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) return null;

      final bytes = await sourceFile.readAsBytes();
      if (bytes.isEmpty) return null;

      // Save permanently in app documents directory under voice_notes/
      final docsDir = await getApplicationDocumentsDirectory();
      final notesDir = Directory('${docsDir.path}/voice_notes');
      if (!await notesDir.exists()) {
        await notesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentPath = '${notesDir.path}/note_$timestamp.m4a';
      await sourceFile.copy(permanentPath);

      // Clean up temp file
      try {
        await sourceFile.delete();
      } catch (_) {}

      debugPrint('[AudioRecorderService] Saved voice note to: $permanentPath (${bytes.length} bytes)');
      return VoiceRecordingResult(
        bytes: bytes,
        permanentFilePath: permanentPath,
      );
    } catch (e) {
      debugPrint('[AudioRecorderService] stopRecordingAndSaveVoiceNote error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Stop recording and return only audio bytes without permanent saving (used for quick voice confirmations)
  Future<Uint8List?> stopRecordingAndGetBytes() async {
    try {
      if (!_isRecording && !(await _recorder.isRecording())) {
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;

      final filePath = path ?? _currentFilePath;
      if (filePath == null) return null;

      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        debugPrint('[AudioRecorderService] Recorded ${bytes.length} bytes');
        // Delete temp file after reading
        try {
          await file.delete();
        } catch (_) {}
        return bytes;
      }
      return null;
    } catch (e) {
      debugPrint('[AudioRecorderService] stopRecording error: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Delete a saved voice note file
  Future<void> deleteVoiceNoteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioRecorderService] Deleted voice note: $path');
      }
    } catch (e) {
      debugPrint('[AudioRecorderService] Error deleting voice note: $e');
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording || await _recorder.isRecording()) {
        final path = await _recorder.stop();
        _isRecording = false;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioRecorderService] cancelRecording error: $e');
      _isRecording = false;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
