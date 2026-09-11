import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/subtitle_track_info.dart';

class LocalSubtitleService {
  static const _extensions = <String>{'srt', 'ass', 'ssa', 'vtt', 'sub'};

  Future<List<SubtitleTrackInfo>> findForVideo(String videoPath) async {
    if (videoPath.isEmpty || videoPath.startsWith('content://')) return const [];

    final video = File(videoPath);
    if (!await video.exists()) return const [];

    final directory = video.parent;
    final videoBase = p.basenameWithoutExtension(video.path).toLowerCase();
    final candidates = <SubtitleTrackInfo>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
      if (!_extensions.contains(ext)) continue;

      final subtitleBase = p.basenameWithoutExtension(entity.path).toLowerCase();
      if (!_matches(videoBase, subtitleBase)) continue;

      final data = await entity.readAsString();
      final language = _detectLanguage(subtitleBase, videoBase);
      candidates.add(
        SubtitleTrackInfo(
          title: language == null ? p.basename(entity.path) : _languageLabel(language),
          language: language,
          data: data,
          source: SubtitleSource.local,
        ),
      );
    }

    candidates.sort((a, b) => a.title.compareTo(b.title));
    return candidates;
  }

  bool _matches(String videoBase, String subtitleBase) {
    if (subtitleBase == videoBase) return true;
    if (subtitleBase.startsWith('$videoBase.')) return true;
    if (videoBase.startsWith('$subtitleBase.')) return true;

    final videoTokens = videoBase.split(RegExp(r'[._ -]+'));
    final subtitleTokens = subtitleBase.split(RegExp(r'[._ -]+'));
    if (subtitleTokens.length < videoTokens.length) return false;

    var matches = 0;
    for (var i = 0; i < videoTokens.length && i < subtitleTokens.length; i++) {
      if (videoTokens[i] == subtitleTokens[i]) matches++;
    }
    return matches >= (videoTokens.length * 0.8).ceil();
  }

  String? _detectLanguage(String subtitleBase, String videoBase) {
    final suffix = subtitleBase.replaceFirst(videoBase, '').replaceFirst(RegExp(r'^[-._ ]+'), '');
    final tokens = suffix.split(RegExp(r'[._ -]+')).where((e) => e.isNotEmpty);
    const supported = <String>{
      'en', 'eng', 'english', 'ta', 'tam', 'tamil', 'ml', 'mal', 'malayalam',
      'hi', 'hin', 'hindi', 'te', 'tel', 'telugu', 'kn', 'kan', 'kannada',
      'fr', 'fra', 'french', 'de', 'deu', 'german', 'es', 'spa', 'spanish',
      'ja', 'jpn', 'japanese', 'ko', 'kor', 'korean',
    };
    return tokens.firstWhere((token) => supported.contains(token), orElse: () => '').let((value) => value.isEmpty ? null : value);
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en': case 'eng': case 'english': return 'English';
      case 'ta': case 'tam': case 'tamil': return 'Tamil';
      case 'ml': case 'mal': case 'malayalam': return 'Malayalam';
      case 'hi': case 'hin': case 'hindi': return 'Hindi';
      case 'te': case 'tel': case 'telugu': return 'Telugu';
      case 'kn': case 'kan': case 'kannada': return 'Kannada';
      case 'fr': case 'fra': case 'french': return 'French';
      case 'de': case 'deu': case 'german': return 'German';
      case 'es': case 'spa': case 'spanish': return 'Spanish';
      case 'ja': case 'jpn': case 'japanese': return 'Japanese';
      case 'ko': case 'kor': case 'korean': return 'Korean';
      default: return code.toUpperCase();
    }
  }
}

extension _NullableString on String {
  T let<T>(T Function(String value) transform) => transform(this);
}
