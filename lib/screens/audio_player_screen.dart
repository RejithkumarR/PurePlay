import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../models/media_file.dart';
import '../utils/constants.dart';
import '../widgets/exit_dialog.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.media});
  final MediaFile media;
  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final Player _player;
  bool _cleanMode = true;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _player.open(Media(widget.media.path), play: true);
  }

  @override
  void dispose() {
    _player.dispose();
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
        appBar: AppBar(
            title: const Text('Audio Player'),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await confirmExit(context, playback: true) &&
                      context.mounted) {
                    Navigator.pop(context);
                  }
                })),
        body: StreamBuilder<Duration>(
          stream: _player.stream.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = _player.state.duration;
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
                                colors: [AppColors.primary, AppColors.accent]),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: .35),
                                  blurRadius: 35)
                            ]),
                        child: const Icon(Icons.music_note_rounded, size: 96)),
                    const SizedBox(height: 30),
                    Text(widget.media.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(widget.media.folderName,
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 28),
                    Slider(
                        value: position.inMilliseconds
                            .clamp(0, max.toInt())
                            .toDouble(),
                        max: max,
                        onChanged: (v) =>
                            _player.seek(Duration(milliseconds: v.toInt()))),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_time(position),
                              style: const TextStyle(color: AppColors.muted)),
                          Text(_time(duration),
                              style: const TextStyle(color: AppColors.muted))
                        ]),
                    const SizedBox(height: 12),
                    StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        builder: (context, snap) {
                          final playing = snap.data ?? false;
                          return IconButton.filled(
                              iconSize: 58,
                              onPressed: _player.playOrPause,
                              icon: Icon(playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded));
                        }),
                    const SizedBox(height: 30),
                    SwitchListTile(
                        value: _cleanMode,
                        onChanged: (v) => setState(() => _cleanMode = v),
                        title: const Text('Clean playback mode'),
                        subtitle: const Text(
                            'Optimized offline playback; no network processing or streaming.'),
                        secondary: const Icon(Icons.auto_awesome_rounded)),
                    const Text(
                        'PurePlay does not remove recorded background noise. True noise removal requires audio DSP/AI processing.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                        textAlign: TextAlign.center),
                  ]),
            );
          },
        ),
      ),
    );
  }
}
