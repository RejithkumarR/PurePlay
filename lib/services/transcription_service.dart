import 'package:whisper_ggml/whisper_ggml.dart';

import '../models/subtitle_track_info.dart';

class TranscriptionService {
  final WhisperController _controller = WhisperController();

  Future<SubtitleTrackInfo> transcribe({
    required String mediaPath,
    String language = 'auto',
    WhisperModel model = WhisperModel.base,
    void Function(double progress)? onProgress,
  }) async {
    if (mediaPath.isEmpty || mediaPath.startsWith('content://')) {
      throw StateError('The selected video does not expose a filesystem path for transcription.');
    }

    final result = await _controller.transcribe(
      model: model,
      audioPath: mediaPath,
      lang: language,
      withSegments: true,
      onProgress: onProgress,
      suppressNonSpeechTokens: true,
    );

    if (result == null) {
      throw StateError('No speech was detected.');
    }

    final segments = result.transcription.segments;
    if (segments.isEmpty) {
      final text = result.transcription.text.trim();
      if (text.isEmpty) throw StateError('No speech was detected.');
      return SubtitleTrackInfo(
        title: 'Generated transcript',
        language: language == 'auto' ? null : language,
        data: _singleSegmentSrt(text),
        source: SubtitleSource.generated,
      );
    }

    final buffer = StringBuffer();
    var index = 1;
    for (final segment in segments) {
      final text = segment.text.trim();
      if (text.isEmpty) continue;
      buffer
        ..writeln(index++)
        ..writeln('${_formatTime(segment.fromTs)} --> ${_formatTime(segment.toTs)}')
        ..writeln(text)
        ..writeln();
    }

    final data = buffer.toString().trim();
    if (data.isEmpty) throw StateError('No speech was detected.');

    return SubtitleTrackInfo(
      title: 'Generated transcript',
      language: language == 'auto' ? null : language,
      data: data,
      source: SubtitleSource.generated,
    );
  }

  String _singleSegmentSrt(String text) {
    return '1\n00:00:00,000 --> 99:59:59,999\n$text\n';
  }

  String _formatTime(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (value.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }

  Future<void> dispose() async {
    await _controller.releaseModel();
  }
}
