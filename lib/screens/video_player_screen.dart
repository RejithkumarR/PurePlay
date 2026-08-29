import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/media_file.dart';
import '../widgets/exit_dialog.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.media});
  final MediaFile media;
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  int _qualityMode = 0; // 0 original, 1 fit, 2 enhanced

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: const PlayerConfiguration());
    _controller = VideoController(_player);
    _player.open(Media(widget.media.path), play: true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  String get _modeLabel => ['Original', 'Fit', 'Enhanced'][_qualityMode];

  void _cycleMode() => setState(() => _qualityMode = (_qualityMode + 1) % 3);

  Widget _video() {
    Widget child =
        Video(controller: _controller, controls: MaterialVideoControls);
    if (_qualityMode == 1) {
      child = FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: child));
    } else if (_qualityMode == 2) {
      // Display-side enhancement: contrast/sharpness-style compensation.
      // This does not create missing source detail; it is intentionally lightweight and offline.
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
                child: child)),
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop &&
            await confirmExit(context, playback: true) &&
            context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(child: _video()),
          SafeArea(
              child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () async {
                          if (await confirmExit(context, playback: true) &&
                              context.mounted) {
                            Navigator.pop(context);
                          }
                        }),
                    Expanded(
                        child: Text(widget.media.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Container(
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: TextButton.icon(
                            onPressed: _cycleMode,
                            icon: const Icon(Icons.hd_outlined,
                                color: Colors.white),
                            label: Text(_modeLabel,
                                style: const TextStyle(color: Colors.white)))),
                  ]))),
        ]),
      ),
    );
  }
}
