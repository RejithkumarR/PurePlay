class SubtitleTrackInfo {
  const SubtitleTrackInfo({
    required this.title,
    required this.language,
    required this.data,
    this.source = SubtitleSource.local,
  });

  final String title;
  final String? language;
  final String data;
  final SubtitleSource source;
}

enum SubtitleSource { embedded, local, online, generated }
