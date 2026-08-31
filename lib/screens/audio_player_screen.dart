import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

import '../models/media_file.dart';
import '../services/audio_playback_service.dart';
import '../utils/constants.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    required this.media,
    this.playlist = const [],
    this.initialIndex = 0,
  });

  final MediaFile media;
  final List<MediaFile> playlist;
  final int initialIndex;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final PurePlayAudioHandler _handler;
  late final List<MediaFile> _playlist;
  late int _currentIndex;
  bool _cleanMode = true;

  @override
  void initState() {
    super.initState();
    _handler = AudioPlaybackService.handler;
    _playlist = widget.playlist.isEmpty
        ? [widget.media]
        : List<MediaFile>.unmodifiable(widget.playlist);
    _currentIndex = widget.initialIndex.clamp(0, _playlist.length - 1).toInt();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    await _handler.setQueue(_playlist, initialIndex: _currentIndex);
    await _handler.play();
  }

  @override
  void dispose() {
    // Keep the audio service alive. This is intentional so playback continues
    // when the user leaves the screen or puts the app in the background.
    super.dispose();
  }

  String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: _handler.mediaItem,
      builder: (context, mediaSnapshot) {
        final current = mediaSnapshot.data;
        final title = current?.title ?? _playlist[_currentIndex].title;
        final folder = current?.album ?? _playlist[_currentIndex].folderName;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Audio Player'),
          ),
          body: StreamBuilder<PlaybackState>(
            stream: _handler.playbackState,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data ?? _handler.playbackState.value;
              final duration = current?.duration ?? Duration.zero;
              final position = state.updatePosition;
              final max = duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0;

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: .35),
                            blurRadius: 35,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note_rounded, size: 96),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      folder,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 28),
                    Slider(
                      value: position.inMilliseconds
                          .clamp(0, max.toInt())
                          .toDouble(),
                      max: max,
                      onChanged: (value) => _handler.seek(
                        Duration(milliseconds: value.toInt()),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _time(position),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          _time(duration),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Previous',
                          onPressed: _currentIndex > 0
                              ? () => _handler.skipToPrevious()
                              : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        const SizedBox(width: 18),
                        IconButton.filled(
                          tooltip: 'Play / Pause',
                          iconSize: 58,
                          onPressed: () => _handler.playbackState.value.playing
                              ? _handler.pause()
                              : _handler.play(),
                          icon: Icon(
                            state.playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: 18),
                        IconButton.filledTonal(
                          tooltip: 'Next',
                          onPressed: _currentIndex < _playlist.length - 1
                              ? () => _handler.skipToNext()
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SwitchListTile(
                      value: _cleanMode,
                      onChanged: (value) => setState(() => _cleanMode = value),
                      title: const Text('Clean playback mode'),
                      subtitle: const Text(
                        'Optimized offline playback; no network processing or streaming.',
                      ),
                      secondary: const Icon(Icons.auto_awesome_rounded),
                    ),
                    const Text(
                      'PurePlay does not remove recorded background noise. True noise removal requires audio DSP/AI processing.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
