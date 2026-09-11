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
      'file_name': fileName,
      'languages': (language ?? 'EN').toLowerCase(),
      'unpack': '1',
      if (year != null) 'year': '$year',
    };

    final uri = Uri.https('api.subdl.com', '/api/v2/subtitles/search', query);
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Subtitle search failed (${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] == false) {
      throw StateError((json['error'] ?? 'Subtitle search failed').toString());
    }

    final subtitles = (json['subtitles'] as List<dynamic>? ?? const []);
    final results = <OnlineSubtitleResult>[];
    for (final raw in subtitles) {
      if (raw is! Map<String, dynamic>) continue;
      final unpackFiles = raw['unpack_files'] as List<dynamic>?;
      if (unpackFiles != null && unpackFiles.isNotEmpty) {
        for (final rawFile in unpackFiles) {
          if (rawFile is! Map<String, dynamic>) continue;
          final url = _absoluteDownloadUrl(rawFile['url']?.toString());
          if (url == null) continue;
          results.add(
            OnlineSubtitleResult(
              title: rawFile['name']?.toString() ?? 'Subtitle',
              language: rawFile['language']?.toString(),
              releaseName: rawFile['release_name']?.toString(),
              downloadUrl: url,
            ),
          );
        }
      } else {
        final url = _absoluteDownloadUrl(raw['url']?.toString());
        if (url == null) continue;
        results.add(
          OnlineSubtitleResult(
            title: raw['name']?.toString() ?? 'Subtitle',
            language: raw['language']?.toString(),
            releaseName: raw['release_name']?.toString(),
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
