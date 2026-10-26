import 'package:flutter/material.dart';
import '../services/voice_note_player_service.dart';

class VoiceNotePlayerWidget extends StatefulWidget {
  final String filePath;
  final bool compact;
  final Color? backgroundColor;

  const VoiceNotePlayerWidget({
    super.key,
    required this.filePath,
    this.compact = false,
    this.backgroundColor,
  });

  @override
  State<VoiceNotePlayerWidget> createState() => _VoiceNotePlayerWidgetState();
}

class _VoiceNotePlayerWidgetState extends State<VoiceNotePlayerWidget> {
  static const Color emeraldGreen = Color(0xFF10B981);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerService = VoiceNotePlayerService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        playerService.currentlyPlayingPath,
        playerService.isPlaying,
        playerService.currentPosition,
        playerService.totalDuration,
      ]),
      builder: (context, _) {
        final isThisPlaying =
            playerService.currentlyPlayingPath.value == widget.filePath &&
            playerService.isPlaying.value;
        final isCurrentFile =
            playerService.currentlyPlayingPath.value == widget.filePath;

        final pos = isCurrentFile
            ? playerService.currentPosition.value
            : Duration.zero;
        final total = isCurrentFile && playerService.totalDuration.value.inMilliseconds > 0
            ? playerService.totalDuration.value
            : null;

        final progress = (total != null && total.inMilliseconds > 0)
            ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        if (widget.compact) {
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => playerService.togglePlay(widget.filePath),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    emeraldGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isThisPlaying
                      ? emeraldGreen
                      : emeraldGreen.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isThisPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: emeraldGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isThisPlaying
                        ? 'Playing (${_formatDuration(pos)})'
                        : 'Voice Note',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: emeraldGreen,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? const Color(0xFF1E293B).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isThisPlaying
                  ? emeraldGreen.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => playerService.togglePlay(widget.filePath),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: emeraldGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isThisPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: emeraldGreen,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.mic_rounded,
                              size: 14,
                              color: emeraldGreen,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Voice Reminder Note',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              isCurrentFile && total != null
                                  ? '${_formatDuration(pos)} / ${_formatDuration(total)}'
                                  : 'Tap to listen',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (isCurrentFile && total != null) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(emeraldGreen),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
