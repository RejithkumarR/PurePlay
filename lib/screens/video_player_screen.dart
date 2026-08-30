import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_file.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.media,
    this.playlist = const [],
    this.initialIndex = 0,
  });

  final MediaFile media;
  final List<MediaFile> playlist;
  final int initialIndex;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late List<MediaFile> _playlist;
  late int _currentIndex;
  late MediaFile _currentMedia;

  int _qualityMode = 0; // 0 original, 1 fit, 2 enhanced
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();

    _player = Player(configuration: const PlayerConfiguration());
    _controller = VideoController(_player);

    _playlist = widget.playlist.isEmpty
        ? [widget.media]
        : List<MediaFile>.unmodifiable(widget.playlist);

    _currentIndex = widget.initialIndex
        .clamp(0, _playlist.length - 1)
        .toInt();
    _currentMedia = _playlist[_currentIndex];

    _openCurrentVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _openCurrentVideo() async {
    await _player.open(
      Media(_currentMedia.path),
      play: true,
    );
  }

  Future<void> _playNext() async {
    if (_currentIndex >= _playlist.length - 1) {
      return;
    }

    setState(() {
      _currentIndex++;
      _currentMedia = _playlist[_currentIndex];
    });

    await _openCurrentVideo();
  }

  Future<void> _playPrevious() async {
    if (_currentIndex <= 0) {
      return;
    }

    setState(() {
      _currentIndex--;
      _currentMedia = _playlist[_currentIndex];
    });

    await _openCurrentVideo();
  }

  Future<void> _seekBySeconds(int seconds) async {
    if (_isSeeking) {
      return;
    }

    final position = _player.state.position;
    final duration = _player.state.duration;

    if (duration <= Duration.zero) {
      return;
    }

    var target = position + Duration(seconds: seconds);

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    if (target > duration) {
      target = duration;
    }

    final wasPlaying = _player.state.playing;

    if (mounted) {
      setState(() => _isSeeking = true);
    }

    try {
      // On Android, explicitly pausing before an absolute seek and then
      // resuming playback makes the video decoder/surface follow the new
      // position reliably. A direct seek could update the audio clock while
      // the video output continued displaying/loading the old frame.
      if (wasPlaying) {
        await _player.pause();
      }

      await _player.seek(target);

      if (wasPlaying) {
        await _player.play();
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeking = false);
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  String get _modeLabel => ['Original', 'Fit', 'Enhanced'][_qualityMode];

  void _cycleMode() {
    setState(() => _qualityMode = (_qualityMode + 1) % 3);
  }

  Widget _video() {
    Widget child = Video(
      controller: _controller,
      controls: MaterialVideoControls,
    );

    if (_qualityMode == 1) {
      child = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: child,
        ),
      );
    } else if (_qualityMode == 2) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          1.08,
          0,
          0,
          0,
          -3,
          0,
          1.08,
          0,
          0,
          -3,
          0,
          0,
          1.08,
          0,
          -3,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: child,
          ),
        ),
      );
    }

    return child;
  }

  Widget _navigationButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            disabledBackgroundColor: Colors.black26,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrevious = _currentIndex > 0;
    final hasNext = _currentIndex < _playlist.length - 1;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _video()),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        _currentMedia.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton.icon(
                        onPressed: _cycleMode,
                        icon: const Icon(
                          Icons.hd_outlined,
                          color: Colors.white,
                        ),
                        label: Text(
                          _modeLabel,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _navigationButton(
                            icon: Icons.skip_previous_rounded,
                            label: 'Previous',
                            onPressed:
                                hasPrevious ? _playPrevious : null,
                          ),
                          const SizedBox(width: 8),
                          _navigationButton(
                            icon: Icons.replay_10_rounded,
                            label: '-10s',
                            onPressed: _isSeeking
                                ? null
                                : () => _seekBySeconds(-10),
                          ),
                          const SizedBox(width: 8),
                          _navigationButton(
                            icon: Icons.forward_10_rounded,
                            label: '+10s',
                            onPressed: _isSeeking
                                ? null
                                : () => _seekBySeconds(10),
                          ),
                          const SizedBox(width: 8),
                          _navigationButton(
                            icon: Icons.skip_next_rounded,
                            label: 'Next',
                            onPressed: hasNext ? _playNext : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
