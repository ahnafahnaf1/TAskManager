import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_task.dart';
import '../services/audio_recorder_service.dart';
import '../services/db_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import 'voice_note_player_widget.dart';

enum VoiceStep {
  checkKey,
  ready,
  recording,
  processing,
  speakingPrompt,
  listeningConfirmation,
  evaluatingConfirmation,
  review,
  error,
}

class VoiceScheduleSheet extends StatefulWidget {
  final VoidCallback onTaskAdded;

  const VoiceScheduleSheet({super.key, required this.onTaskAdded});

  static Future<void> show(BuildContext context, {required VoidCallback onTaskAdded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceScheduleSheet(onTaskAdded: onTaskAdded),
    );
  }

  @override
  State<VoiceScheduleSheet> createState() => _VoiceScheduleSheetState();
}

class _VoiceScheduleSheetState extends State<VoiceScheduleSheet>
    with SingleTickerProviderStateMixin {
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color darkBgColor = Color(0xFF1E1E1E);
  static const Color darkCardColor = Color(0xFF262626);

  VoiceStep _currentStep = VoiceStep.ready;
  String _originalHeardSpeech = '';
  String? _errorMessage;
  String? _savedVoiceNotePath;
  String? _confirmationHint;

  // Recording timer
  Timer? _recordDurationTimer;
  int _recordSeconds = 0;

  // Confirmation countdown timer
  Timer? _confirmCountdownTimer;
  int _confirmCountdownSeconds = 4;

  // Key input state (if not configured)
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isSavingKey = false;

  // Parsed Task state
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _timeAssumed = false;
  bool _isSavingTask = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkSetupAndStart();
  }

  @override
  void dispose() {
    _recordDurationTimer?.cancel();
    _confirmCountdownTimer?.cancel();
    _pulseController.dispose();
    _apiKeyController.dispose();
    _titleController.dispose();
    TtsService.instance.stop();
    AudioRecorderService.instance.cancelRecording();
    super.dispose();
  }

  Future<void> _checkSetupAndStart() async {
    final key = await GeminiService.instance.getApiKey();
    if (key == null || key.isEmpty) {
      if (mounted) {
        setState(() {
          _currentStep = VoiceStep.checkKey;
        });
      }
      return;
    }

    _startRecording();
  }

  Future<void> _startRecording() async {
    TtsService.instance.stop();
    _confirmCountdownTimer?.cancel();

    setState(() {
      _currentStep = VoiceStep.recording;
      _originalHeardSpeech = '';
      _errorMessage = null;
      _recordSeconds = 0;
      _confirmationHint = null;
    });

    final started = await AudioRecorderService.instance.startRecording();
    if (!started) {
      if (mounted) {
        setState(() {
          _currentStep = VoiceStep.error;
          _errorMessage = 'Microphone permission is required to record audio.';
        });
      }
      return;
    }

    _recordDurationTimer?.cancel();
    _recordDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _recordSeconds++;
      });
      // Automatically finish recording after 20 seconds
      if (_recordSeconds >= 20) {
        _stopRecordingAndSend();
      }
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordDurationTimer?.cancel();

    setState(() {
      _currentStep = VoiceStep.processing;
      _errorMessage = null;
    });

    try {
      final recordResult = await AudioRecorderService.instance.stopRecordingAndSaveVoiceNote();
      if (recordResult == null || recordResult.bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _currentStep = VoiceStep.error;
            _errorMessage = 'No audio recorded. Please tap and speak clearly.';
          });
        }
        return;
      }

      _savedVoiceNotePath = recordResult.permanentFilePath;

      final parsed = await GeminiService.instance.parseVoiceAudio(recordResult.bytes);
      final DateTime dt = parsed['scheduledTime'] as DateTime;

      if (!mounted) return;
      setState(() {
        _titleController.text = parsed['title'] as String;
        _originalHeardSpeech = parsed['originalSpeech'] as String? ?? '';
        _selectedDate = DateTime(dt.year, dt.month, dt.day);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        _timeAssumed = parsed['timeAssumed'] == true;
      });

      // Initiate hands-free conversational voice confirmation
      _askVoiceConfirmation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = VoiceStep.error;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _askVoiceConfirmation() async {
    if (!mounted) return;
    setState(() {
      _currentStep = VoiceStep.speakingPrompt;
    });

    final formattedDate = DateFormat('MMMM d').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);
    final title = _titleController.text.trim();

    final spokenPrompt = 'Schedule $title on $formattedDate at $formattedTime? Say Yes to save, or No to cancel.';

    await TtsService.instance.speakAndWait(spokenPrompt, timeout: const Duration(seconds: 7));

    if (!mounted || _currentStep != VoiceStep.speakingPrompt) return;

    _startListeningConfirmation();
  }

  Future<void> _startListeningConfirmation() async {
    if (!mounted) return;

    final started = await AudioRecorderService.instance.startRecording();
    if (!started) {
      if (mounted) {
        setState(() {
          _currentStep = VoiceStep.review;
          _confirmationHint = 'Could not access mic. Please tap Confirm & Schedule below.';
        });
      }
      return;
    }

    setState(() {
      _currentStep = VoiceStep.listeningConfirmation;
      _confirmCountdownSeconds = 4;
    });

    _confirmCountdownTimer?.cancel();
    _confirmCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _confirmCountdownSeconds--;
      });

      if (_confirmCountdownSeconds <= 0) {
        timer.cancel();
        _evaluateVoiceResponse();
      }
    });
  }

  Future<void> _evaluateVoiceResponse() async {
    _confirmCountdownTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _currentStep = VoiceStep.evaluatingConfirmation;
    });

    try {
      final confirmationBytes = await AudioRecorderService.instance.stopRecordingAndGetBytes();
      if (confirmationBytes == null || confirmationBytes.isEmpty) {
        if (mounted) {
          setState(() {
            _currentStep = VoiceStep.review;
            _confirmationHint = "No response heard. Please tap Confirm or speak again.";
          });
        }
        return;
      }

      final confirmed = await GeminiService.instance.evaluateVoiceConfirmation(confirmationBytes);

      if (!mounted) return;

      if (confirmed == true) {
        // User said Yes / Oom / Aam / Sari -> Automatically save!
        await _saveFinalTask();
      } else if (confirmed == false) {
        // User said No / Illai / Vendaam / Cancel -> Reject & clean up
        await AudioRecorderService.instance.deleteVoiceNoteFile(_savedVoiceNotePath);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cancel_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Task scheduling cancelled.'),
                ],
              ),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      } else {
        // Silence or unclear -> Stay on review so user can confirm or record again
        setState(() {
          _currentStep = VoiceStep.review;
          _confirmationHint = "Could not clearly understand. Say Yes or No, or tap below:";
        });
      }
    } catch (e) {
      debugPrint('Error evaluating confirmation: $e');
      if (mounted) {
        setState(() {
          _currentStep = VoiceStep.review;
          _confirmationHint = "Please review and tap Confirm & Schedule.";
        });
      }
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isSavingKey = true;
    });

    await GeminiService.instance.saveApiKey(key);

    if (mounted) {
      setState(() {
        _isSavingKey = false;
      });
      _startRecording();
    }
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: emeraldGreen,
                  surface: darkBgColor,
                  onSurface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: emeraldGreen,
                  surface: darkBgColor,
                  onSurface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeAssumed = false;
      });
    }
  }

  Future<void> _saveFinalTask() async {
    TtsService.instance.stop();
    _confirmCountdownTimer?.cancel();
    AudioRecorderService.instance.cancelRecording();

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final targetDateTime = _combinedDateTime;
    final now = DateTime.now();
    if (targetDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled time cannot be in the past.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isSavingTask = true;
    });

    try {
      final task = ScheduleTask(
        title: title,
        scheduledTime: targetDateTime,
        status: TaskStatus.pending.value,
        voiceNotePath: _savedVoiceNotePath,
      );

      final insertedId = await DBService.instance.insertTask(task);
      final persistedTask = task.copyWith(id: insertedId);
      await NotificationService.instance.scheduleTaskAlerts(persistedTask);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onTaskAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Scheduled "$title" for ${DateFormat('MMM d, h:mm a').format(targetDateTime)}'),
                ),
              ],
            ),
            backgroundColor: emeraldGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingTask = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: darkBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: emeraldGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mic_rounded, color: emeraldGreen, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Voice Scheduler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () {
                    TtsService.instance.stop();
                    _confirmCountdownTimer?.cancel();
                    AudioRecorderService.instance.cancelRecording();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Content
            if (_currentStep == VoiceStep.checkKey) _buildApiKeySetup(),
            if (_currentStep == VoiceStep.ready) _buildReadyView(),
            if (_currentStep == VoiceStep.recording) _buildRecordingView(),
            if (_currentStep == VoiceStep.processing) _buildProcessingView(),
            if (_currentStep == VoiceStep.speakingPrompt) _buildSpeakingPromptView(),
            if (_currentStep == VoiceStep.listeningConfirmation) _buildListeningConfirmationView(),
            if (_currentStep == VoiceStep.evaluatingConfirmation) _buildEvaluatingConfirmationView(),
            if (_currentStep == VoiceStep.review) _buildReviewView(),
            if (_currentStep == VoiceStep.error) _buildErrorView(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeySetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.key_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Gemini API Key Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'A Google Gemini API Key is required to recognize and schedule tasks automatically (100% Free - 1,500 tasks/day).',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Paste API Key here (AIza...)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: emeraldGreen),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSavingKey ? null : _saveApiKey,
          style: ElevatedButton.styleFrom(
            backgroundColor: emeraldGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSavingKey
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Save & Start Recording',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
      ],
    );
  }

  Widget _buildReadyView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _startRecording,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emeraldGreen,
              boxShadow: [
                BoxShadow(
                  color: emeraldGreen.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tap microphone & speak',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Speak in Tamil, Tanglish, or English. Gemini AI will automatically extract title, date & time.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecordingView() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          _formatTimer(_recordSeconds),
          style: const TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),

        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _stopRecordingAndSend,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 44),
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Speaking... Tap stop or wait when finished',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  AudioRecorderService.instance.cancelRecording();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _stopRecordingAndSend,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done & Process'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: const Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: emeraldGreen,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Gemini AI is analyzing audio...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Extracting task details and date/time...',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingPromptView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: emeraldGreen.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up_rounded, color: emeraldGreen, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Asking for Confirmation...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Schedule "${_titleController.text}" on ${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'Speak "Yes" or "No" right after the prompt',
                style: TextStyle(color: emeraldGreen, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Allows user to skip speaking and save directly
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  TtsService.instance.stop();
                  setState(() => _currentStep = VoiceStep.review);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Review Details'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveFinalTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm Now'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListeningConfirmationView() {
    return Column(
      children: [
        const SizedBox(height: 10),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emeraldGreen,
              boxShadow: [
                BoxShadow(
                  color: emeraldGreen.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$_confirmCountdownSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Listening for your confirmation...',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Say "Yes" / "Oom" / "Aam" to save\nOr "No" / "Illai" / "Cancel" to reject',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _confirmCountdownTimer?.cancel();
                  AudioRecorderService.instance.cancelRecording();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reject (No)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveFinalTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Confirm (Yes)'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEvaluatingConfirmationView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: const Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: emeraldGreen, strokeWidth: 3),
          ),
          SizedBox(height: 18),
          Text(
            'Verifying voice response...',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Processing your spoken confirmation...',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView() {
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spoken original preview
        if (_originalHeardSpeech.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: darkCardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: emeraldGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"$_originalHeardSpeech"',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Attached Voice Note Preview Player
        if (_savedVoiceNotePath != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: darkCardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: emeraldGreen.withValues(alpha: 0.3)),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: const TextTheme(
                  bodyMedium: TextStyle(color: Colors.white),
                ),
              ),
              child: VoiceNotePlayerWidget(
                filePath: _savedVoiceNotePath!,
                backgroundColor: darkCardColor,
              ),
            ),
          ),
        ],

        // Confirmation Hint
        if (_confirmationHint != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _confirmationHint!,
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Title Input
        const Text(
          'Task Title',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: darkCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: emeraldGreen, width: 1.5),
            ),
            prefixIcon: const Icon(Icons.task_alt_rounded, color: emeraldGreen),
          ),
        ),
        const SizedBox(height: 14),

        // Date and Time selectors
        Row(
          children: [
            // Date Picker Card
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: darkCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: emeraldGreen, size: 16),
                          SizedBox(width: 6),
                          Text('Date', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Time Picker Card
            Expanded(
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: darkCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _timeAssumed ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: _timeAssumed ? Colors.amber : emeraldGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeAssumed ? 'Time (Defaulted)' : 'Time',
                            style: TextStyle(
                              color: _timeAssumed ? Colors.amber : Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedTime,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_timeAssumed) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.amber, size: 14),
              SizedBox(width: 6),
              Text(
                'No time specified. Defaulted to 9:00 AM.',
                style: TextStyle(color: Colors.amber, fontSize: 11),
              ),
            ],
          ),
        ],

        const SizedBox(height: 18),

        // Actions
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _startRecording,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Record Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSavingTask ? null : _saveFinalTask,
                icon: _isSavingTask
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Confirm & Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
        const SizedBox(height: 14),
        Text(
          _errorMessage ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
