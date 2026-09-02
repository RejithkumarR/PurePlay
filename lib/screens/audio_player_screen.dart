import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../models/media_file.dart';
import '../services/audio_playback_service.dart';
import '../services/media_scanner.dart';
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
  late final Future<PurePlayAudioHandler> _handlerFuture;
  List<MediaFile> _playlist = const [];
  int _initialIndex = 0;
  bool _cleanMode = true;
  bool _loadingPlaylist = true;

  @override
  void initState() {
    super.initState();
    _handlerFuture = AudioPlaybackService.initialize();
    _preparePlaylist();
  }

  void _preparePlaylist() {
    final cachedAudio = MediaScanner.cachedMedia
        .where((file) => file.type == MediaType.audio)
        .toList(growable: false);
    final suppliedPlaylist = widget.playlist.isEmpty
        ? <MediaFile>[]
        : List<MediaFile>.from(widget.playlist);

    _playlist = suppliedPlaylist.isNotEmpty
        ? List<MediaFile>.unmodifiable(suppliedPlaylist)
        : cachedAudio.isNotEmpty
            ? List<MediaFile>.unmodifiable(cachedAudio)
            : [widget.media];

    final requestedIndex = widget.playlist.isNotEmpty
        ? widget.initialIndex
        : _playlist.indexWhere((file) => file.path == widget.media.path);
    _initialIndex = (requestedIndex < 0 ? 0 : requestedIndex)
        .clamp(0, _playlist.length - 1)
        .toInt();
  }

  Future<void> _loadPlaylist(PurePlayAudioHandler handler) async {
    if (!_loadingPlaylist) return;
    await handler.setQueue(_playlist, initialIndex: _initialIndex);
    await handler.play();
    if (mounted) setState(() => _loadingPlaylist = false);
  }

  String _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _showAllSongs(PurePlayAudioHandler handler) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          minChildSize: .45,
          maxChildSize: .95,
          builder: (_, scrollController) {
            return StreamBuilder<MediaItem?>(
              stream: handler.mediaItem,
              builder: (context, snapshot) {
                final currentId = snapshot.data?.id;
                final songs = handler.queueFiles;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'All Songs',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text('${songs.length} songs', style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: songs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (_, index) {
                          final song = songs[index];
                          final selected = song.path == currentId;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surface2,
                              child: Icon(
                                selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                color: AppColors.accent,
                              ),
                            ),
                            title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(song.folderName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: selected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                                : null,
                            onTap: () async {
                              await handler.playQueueIndex(index);
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _shuffle(PurePlayAudioHandler handler) async {
    if (handler.queueFiles.length < 2) return;
    await handler.shuffleQueue();
    if (!mounted) return;
    setState(() => _playlist = handler.queueFiles);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Songs shuffled')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PurePlayAudioHandler>(
      future: _handlerFuture,
      builder: (context, handlerSnapshot) {
        if (handlerSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (handlerSnapshot.hasError || handlerSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Audio Player')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Audio playback service could not be started.\n${handlerSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final handler = handlerSnapshot.data!;
        if (_loadingPlaylist) {
          _loadPlaylist(handler);
        }

        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          builder: (context, mediaSnapshot) {
            final current = mediaSnapshot.data;
            final songs = handler.queueFiles.isNotEmpty ? handler.queueFiles : _playlist;
            final fallbackIndex = _initialIndex.clamp(0, songs.length - 1).toInt();
            final currentIndex = songs.indexWhere((file) => file.path == current?.id);
            final safeIndex = currentIndex >= 0 ? currentIndex : fallbackIndex;
            final title = current?.title ?? songs[safeIndex].title;
            final folder = current?.album ?? songs[safeIndex].folderName;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Audio Player'),
                actions: [
                  IconButton(
                    tooltip: 'All songs',
                    onPressed: () => _showAllSongs(handler),
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                  IconButton(
                    tooltip: 'Shuffle songs',
                    onPressed: songs.length > 1 ? () => _shuffle(handler) : null,
                    icon: const Icon(Icons.shuffle_rounded),
                  ),
                ],
              ),
              body: StreamBuilder<PlaybackState>(
                stream: handler.playbackState,
                builder: (context, stateSnapshot) {
                  final state = stateSnapshot.data ?? handler.playbackState.value;
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(folder, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 28),
                        Slider(
                          value: position.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                          max: max,
                          onChanged: (value) => handler.seek(Duration(milliseconds: value.toInt())),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_time(position), style: const TextStyle(color: AppColors.muted)),
                            Text(_time(duration), style: const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Previous',
                              onPressed: safeIndex > 0 ? handler.skipToPrevious : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            const SizedBox(width: 18),
                            IconButton.filled(
                              tooltip: 'Play / Pause',
                              iconSize: 58,
                              onPressed: state.playing ? handler.pause : handler.play,
                              icon: Icon(
                                state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              ),
                            ),
                            const SizedBox(width: 18),
                            IconButton.filledTonal(
                              tooltip: 'Next',
                              onPressed: safeIndex < songs.length - 1 ? handler.skipToNext : null,
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
      },
    );
  }
}
