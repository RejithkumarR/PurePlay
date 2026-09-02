import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_file.dart';

class PurePlayAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<MediaFile> _queueFiles = const [];

  PurePlayAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index >= 0 && index < items.length) {
        mediaItem.add(items[index]);
      }
    });
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  List<MediaFile> get queueFiles => List<MediaFile>.unmodifiable(_queueFiles);

  Future<void> setQueue(List<MediaFile> media, {int initialIndex = 0}) async {
    _queueFiles = List<MediaFile>.unmodifiable(media);
    final items = _queueFiles.map(_toMediaItem).toList(growable: false);
    final sources = <AudioSource>[];
    for (var index = 0; index < _queueFiles.length; index++) {
      sources.add(AudioSource.uri(_toUri(_queueFiles[index].path), tag: items[index]));
    }

    queue.add(items);
    if (items.isEmpty) return;

    final safeIndex = initialIndex.clamp(0, items.length - 1).toInt();
    await _player.setAudioSources(sources, initialIndex: safeIndex, preload: true);
    mediaItem.add(items[safeIndex]);
  }

  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= _queueFiles.length) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> shuffleQueue() async {
    if (_queueFiles.length < 2) return;

    final currentPath = _queueFiles[_player.currentIndex ?? 0].path;
    final currentPosition = _player.position;
    final wasPlaying = _player.playing;
    final shuffled = [..._queueFiles]..shuffle(Random());

    final currentIndex = shuffled.indexWhere((file) => file.path == currentPath);
    final current = shuffled.removeAt(currentIndex);
    shuffled.insert(0, current);

    await setQueue(shuffled, initialIndex: 0);
    await _player.seek(currentPosition);
    if (wasPlaying) await _player.play();
  }

  MediaItem _toMediaItem(MediaFile file) => MediaItem(
        id: file.path,
        title: file.title,
        album: file.folderName,
      );

  Uri _toUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri;
    return Uri.file(value);
  }

  void _broadcastState(PlaybackEvent event) {
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (_player.hasPrevious) MediaControl.skipToPrevious,
          _player.playing ? MediaControl.pause : MediaControl.play,
          if (_player.hasNext) MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> fastForward() async {
    final duration = _player.duration ?? Duration.zero;
    final target = _player.position + const Duration(seconds: 10);
    await _player.seek(target > duration ? duration : target);
  }

  @override
  Future<void> rewind() async {
    final target = _player.position - const Duration(seconds: 10);
    await _player.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> dispose() => _player.dispose();
}

class AudioPlaybackService {
  static PurePlayAudioHandler? _handler;
  static Future<PurePlayAudioHandler>? _initialization;

  static PurePlayAudioHandler? get handlerOrNull => _handler;

  static Future<PurePlayAudioHandler> initialize() {
    final existing = _handler;
    if (existing != null) return Future.value(existing);
    return _initialization ??= _initialize();
  }

  static Future<PurePlayAudioHandler> _initialize() async {
    try {
      final handler = await AudioService.init(
        builder: () => PurePlayAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.pureplay.localplayer.audio',
          androidNotificationChannelName: 'PurePlay Audio Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'mipmap/ic_launcher',
          rewindInterval: const Duration(seconds: 10),
          fastForwardInterval: const Duration(seconds: 10),
        ),
      );
      _handler = handler;
      return handler;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }
}
