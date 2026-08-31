import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_file.dart';

class PurePlayAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  PurePlayAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index >= 0 && index < items.length) {
        mediaItem.add(items[index]);
      }
    });
    _player.playerStateStream.listen((_) => _broadcastState(_player.playbackEvent));
  }

  Future<void> setQueue(List<MediaFile> media, {int initialIndex = 0}) async {
    final items = media
        .map(
          (file) => MediaItem(
            id: file.path,
            title: file.title,
            album: file.folderName,
            duration: null,
          ),
        )
        .toList(growable: false);

    final sources = media
        .map(
          (file) => AudioSource.uri(
            _toUri(file.path),
            tag: items[media.indexOf(file)],
          ),
        )
        .toList(growable: false);

    queue.add(items);
    if (items.isEmpty) return;

    final safeIndex = initialIndex.clamp(0, items.length - 1).toInt();
    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      preload: true,
    );
    mediaItem.add(items[safeIndex]);
  }

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
  Future<void> fastForward() => _player.seek(
        _player.position + const Duration(seconds: 10),
      );

  @override
  Future<void> rewind() => _player.seek(
        _player.position - const Duration(seconds: 10),
      );

  Future<void> dispose() => _player.dispose();
}

class AudioPlaybackService {
  static late final PurePlayAudioHandler handler;

  static Future<void> initialize() async {
    handler = await AudioService.init(
      builder: () => PurePlayAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pureplay.localplayer.audio',
        androidNotificationChannelName: 'PurePlay Audio Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
        rewindInterval: Duration(seconds: 10),
        fastForwardInterval: Duration(seconds: 10),
      ),
    );
  }
}
