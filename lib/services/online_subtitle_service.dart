import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subtitle_track_info.dart';

class OnlineSubtitleResult {
  const OnlineSubtitleResult({
    required this.title,
    required this.language,
    required this.releaseName,
    required this.downloadUrl,
  });

  final String title;
  final String? language;
  final String? releaseName;
  final String downloadUrl;
}

class OnlineSubtitleService {
  OnlineSubtitleService({String? apiKey}) : _apiKey = apiKey ?? const String.fromEnvironment('SUBDL_API_KEY');

  final String _apiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<OnlineSubtitleResult>> search({
    required String fileName,
    String? language,
    int? year,
  }) async {
    if (!isConfigured) {
      throw StateError('SubDL API key is not configured. Build with --dart-define=SUBDL_API_KEY=YOUR_KEY.');
    }

    final query = <String, String>{
      'api_key': _apiKey,
      'file_name': fileName,
      'languages': (language ?? 'EN').toUpperCase(),
      'unpack': '1',
      'releases': '1',
      'client': 'subdl_player',
      if (year != null) 'year': '$year',
    };

    final uri = Uri.https('api.subdl.com', '/api/v1/subtitles', query);
    final response = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (response.statusCode != 200) {
      throw StateError('Subtitle search failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != true) {
      throw StateError((json['error'] ?? 'Subtitle search failed').toString());
    }

    final subtitles = (json['subtitles'] as List<dynamic>? ?? const []);
    final results = <OnlineSubtitleResult>[];
    for (final raw in subtitles) {
      final subtitle = raw as Map<String, dynamic>;
      final unpackFiles = subtitle['unpack_files'] as List<dynamic>?;
      if (unpackFiles != null && unpackFiles.isNotEmpty) {
        for (final rawFile in unpackFiles) {
          final file = rawFile as Map<String, dynamic>;
          final url = _absoluteDownloadUrl(file['url']?.toString());
          if (url == null) continue;
          results.add(
            OnlineSubtitleResult(
              title: file['name']?.toString() ?? 'Subtitle',
              language: file['language']?.toString(),
              releaseName: file['release_name']?.toString(),
              downloadUrl: url,
            ),
          );
        }
      } else {
        final url = _absoluteDownloadUrl(subtitle['url']?.toString());
        if (url == null) continue;
        results.add(
          OnlineSubtitleResult(
            title: subtitle['name']?.toString() ?? 'Subtitle',
            language: subtitle['language']?.toString(),
            releaseName: subtitle['release_name']?.toString(),
            downloadUrl: url,
          ),
        );
      }
    }
    return results;
  }

  Future<SubtitleTrackInfo> download(OnlineSubtitleResult result) async {
    final response = await http.get(Uri.parse(result.downloadUrl));
    if (response.statusCode != 200) {
      throw StateError('Unable to download subtitle (${response.statusCode}).');
    }
    final data = utf8.decode(response.bodyBytes, allowMalformed: true);
    return SubtitleTrackInfo(
      title: result.title,
      language: result.language,
      data: data,
      source: SubtitleSource.online,
    );
  }

  String? _absoluteDownloadUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return 'https://dl.subdl.com${value.startsWith('/') ? value : '/$value'}';
  }
}
