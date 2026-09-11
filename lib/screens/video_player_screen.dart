import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/media_file.dart';
import '../models/subtitle_track_info.dart';
import '../services/local_subtitle_service.dart';
import '../services/online_subtitle_service.dart';
import '../services/transcription_service.dart';

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
  late final TranscriptionService _transcriptionService;
  late List<MediaFile> _playlist;
  late int _currentIndex;
  late MediaFile _currentMedia;

  final _localSubtitleService = LocalSubtitleService();
  final _onlineSubtitleService = OnlineSubtitleService();

  int _qualityMode = 0;
  bool _isSeeking = false;
  bool _subtitleBusy = false;
  List<SubtitleTrackInfo> _localSubtitles = const [];
  SubtitleTrackInfo? _activeExternalSubtitle;

  StreamSubscription<List<SubtitleTrack>>? _subtitleTracksSubscription;

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: const PlayerConfiguration());
    _controller = VideoController(_player);
    _transcriptionService = TranscriptionService();
    _playlist = widget.playlist.isEmpty
        ? [widget.media]
        : List<MediaFile>.unmodifiable(widget.playlist);
    _currentIndex = widget.initialIndex.clamp(0, _playlist.length - 1).toInt();
    _currentMedia = _playlist[_currentIndex];
    _subtitleTracksSubscription = _player.stream.tracks.map((tracks) => tracks.subtitle).listen((_) {
      if (mounted) setState(() {});
    });
    _openCurrentVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _openCurrentVideo({Duration? startAt, bool? play}) async {
    final media = startAt != null
        ? Media(_currentMedia.path, start: startAt)
        : Media(_currentMedia.path);
    await _player.open(media, play: play ?? true);
    if (!mounted) return;

    _activeExternalSubtitle = null;
    _localSubtitles = await _localSubtitleService.findForVideo(_currentMedia.path);
    if (!mounted) return;

    final embedded = _player.state.tracks.subtitle
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    if (embedded.isEmpty && _localSubtitles.isNotEmpty) {
      await _applySubtitle(_localSubtitles.first);
    } else if (embedded.isEmpty && _onlineSubtitleService.isConfigured) {
      unawaited(_searchOnlineAutomatically());
    }
    if (mounted) setState(() {});
  }

  Future<void> _searchOnlineAutomatically() async {
    try {
      final results = await _onlineSubtitleService.search(fileName: _currentMedia.title);
      if (!mounted || results.isEmpty) return;
      await _applySubtitle(await _onlineSubtitleService.download(results.first));
    } catch (_) {
      // Online subtitle discovery is optional and must never block playback.
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex >= _playlist.length - 1) return;
    setState(() {
      _currentIndex++;
      _currentMedia = _playlist[_currentIndex];
    });
    await _openCurrentVideo();
  }

  Future<void> _playPrevious() async {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex--;
      _currentMedia = _playlist[_currentIndex];
    });
    await _openCurrentVideo();
  }

  Future<void> _seekBySeconds(int seconds) async {
    if (_isSeeking) return;

    final position = _player.state.position;
    final duration = _player.state.duration;
    if (duration <= Duration.zero) return;

    var target = position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    final wasPlaying = _player.state.playing;
    if (mounted) setState(() => _isSeeking = true);

    try {
      await _player.open(
        Media(_currentMedia.path, start: target),
        play: wasPlaying,
      );
      if (_activeExternalSubtitle != null) {
        await _player.setSubtitleTrack(
          SubtitleTrack.data(
            _activeExternalSubtitle!.data,
            title: _activeExternalSubtitle!.title,
            language: _activeExternalSubtitle!.language,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeking = false);
    }
  }

  Future<void> _applySubtitle(SubtitleTrackInfo subtitle) async {
    await _player.setSubtitleTrack(
      SubtitleTrack.data(
        subtitle.data,
        title: subtitle.title,
        language: subtitle.language,
      ),
    );
    if (mounted) setState(() => _activeExternalSubtitle = subtitle);
  }

  Future<void> _pickSubtitleFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'ass', 'ssa', 'vtt', 'sub'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('Unable to read the selected subtitle file.');
      return;
    }

    final data = utf8.decode(bytes, allowMalformed: true);
    await _applySubtitle(
      SubtitleTrackInfo(
        title: file.name,
        language: null,
        data: data,
        source: SubtitleSource.local,
      ),
    );
  }

  Future<void> _showAudioTracks() async {
    final tracks = _player.state.tracks.audio
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    if (tracks.isEmpty) {
      _showMessage('No alternate audio tracks found in this video.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.audiotrack),
              title: Text('Audio language'),
            ),
            for (final track in tracks)
              ListTile(
                leading: Icon(
                  _player.state.track.audio.id == track.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(track.title?.trim().isNotEmpty == true
                    ? track.title!
                    : (track.language?.toUpperCase() ?? 'Audio')),
                subtitle: Text(track.language?.toUpperCase() ?? 'Unknown language'),
                onTap: () async {
                  await _player.setAudioTrack(track);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubtitleTracks() async {
    final embedded = _player.state.tracks.subtitle
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.closed_caption_outlined),
              title: Text('Subtitles'),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_off_outlined),
              title: const Text('Off'),
              onTap: () async {
                await _player.setSubtitleTrack(SubtitleTrack.no());
                if (context.mounted) Navigator.pop(context);
                if (mounted) setState(() => _activeExternalSubtitle = null);
              },
            ),
            for (final track in embedded)
              ListTile(
                leading: const Icon(Icons.closed_caption),
                title: Text(track.title?.trim().isNotEmpty == true
                    ? track.title!
                    : 'Embedded subtitle'),
                subtitle: Text(track.language?.toUpperCase() ?? 'Embedded'),
                onTap: () async {
                  await _player.setSubtitleTrack(track);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() => _activeExternalSubtitle = null);
                },
              ),
            for (final subtitle in _localSubtitles)
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: Text(subtitle.title),
                subtitle: Text(subtitle.language?.toUpperCase() ?? 'Local file'),
                onTap: () async {
                  await _applySubtitle(subtitle);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            if (_activeExternalSubtitle?.source == SubtitleSource.generated)
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(_activeExternalSubtitle!.title),
                subtitle: const Text('Generated from audio'),
                onTap: () => Navigator.pop(context),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Load subtitle file'),
              onTap: () async {
                Navigator.pop(context);
                await _pickSubtitleFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Search subtitles online'),
              subtitle: Text(_onlineSubtitleService.isConfigured
                  ? 'Search SubDL'
                  : 'Configure SUBDL_API_KEY to enable'),
              onTap: () async {
                Navigator.pop(context);
                await _searchOnlineManually();
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over),
              title: const Text('Generate from audio'),
              subtitle: const Text('Offline Whisper transcription'),
              onTap: () async {
                Navigator.pop(context);
                await _generateSubtitleFromAudio();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchOnlineManually() async {
    if (!_onlineSubtitleService.isConfigured) {
      _showMessage('Online subtitles require a SubDL API key.');
      return;
    }

    final language = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Subtitle language'),
        children: [
          for (final item in const {'EN': 'English', 'TA': 'Tamil', 'ML': 'Malayalam', 'HI': 'Hindi'})
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.key),
              child: Text(item.value),
            ),
        ],
      ),
    );
    if (language == null) return;

    setState(() => _subtitleBusy = true);
    try {
      final results = await _onlineSubtitleService.search(
        fileName: _currentMedia.title,
        language: language,
      );
      if (!mounted) return;
      if (results.isEmpty) {
        _showMessage('No subtitles found for ${_currentMedia.title}.');
        return;
      }
      final selected = await showModalBottomSheet<OnlineSubtitleResult>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return ListTile(
                leading: const Icon(Icons.subtitles),
                title: Text(item.title),
                subtitle: Text(item.releaseName ?? item.language ?? language),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      );
      if (selected != null) {
        await _applySubtitle(await _onlineSubtitleService.download(selected));
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _subtitleBusy = false);
    }
  }

  Future<void> _generateSubtitleFromAudio() async {
    final language = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transcription language'),
        children: [
          for (final item in const {'auto': 'Auto detect', 'en': 'English', 'ta': 'Tamil', 'ml': 'Malayalam', 'hi': 'Hindi'})
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item.key),
              child: Text(item.value),
            ),
        ],
      ),
    );
    if (language == null) return;

    setState(() => _subtitleBusy = true);
    try {
      final subtitle = await _transcriptionService.transcribe(
        mediaPath: _currentMedia.path,
        language: language,
        model: WhisperModel.base,
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );
      await _applySubtitle(subtitle);
      if (mounted) _showMessage('Subtitle generated locally from the audio.');
    } catch (error) {
      if (mounted) _showMessage('Transcription failed: $error');
    } finally {
      if (mounted) setState(() => _subtitleBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _subtitleTracksSubscription?.cancel();
    _transcriptionService.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  String get _modeLabel => ['Original', 'Fit', 'Enhanced'][_qualityMode];

  void _cycleMode() => setState(() => _qualityMode = (_qualityMode + 1) % 3);

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
          1.08, 0, 0, 0, -3,
          0, 1.08, 0, 0, -3,
          0, 0, 1.08, 0, -3,
          0, 0, 0, 1, 0,
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

    return Scaffold(
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                  IconButton(
                    onPressed: _showAudioTracks,
                    tooltip: 'Audio language',
                    icon: const Icon(Icons.audiotrack, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _showSubtitleTracks,
                    tooltip: 'Subtitles',
                    icon: Badge(
                      isLabelVisible: _subtitleBusy,
                      child: const Icon(Icons.closed_caption_outlined, color: Colors.white),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton.icon(
                      onPressed: _cycleMode,
                      icon: const Icon(Icons.hd_outlined, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _navigationButton(
                          icon: Icons.skip_previous_rounded,
                          label: 'Previous',
                          onPressed: hasPrevious ? _playPrevious : null,
                        ),
                        const SizedBox(width: 8),
                        _navigationButton(
                          icon: Icons.replay_10_rounded,
                          label: '-10s',
                          onPressed: _isSeeking ? null : () => _seekBySeconds(-10),
                        ),
                        const SizedBox(width: 8),
                        _navigationButton(
                          icon: Icons.forward_10_rounded,
                          label: '+10s',
                          onPressed: _isSeeking ? null : () => _seekBySeconds(10),
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
    );
  }
}
