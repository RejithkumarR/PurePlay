enum MediaType { video, audio }

class MediaFile {
  const MediaFile({
    required this.path,
    required this.title,
    required this.folderName,
    required this.relativePath,
    required this.sizeInBytes,
    required this.modifiedDate,
    required this.type,
  });

  final String path;
  final String title;
  final String folderName;
  final String relativePath;
  final int sizeInBytes;
  final DateTime modifiedDate;
  final MediaType type;

  String get formattedSize {
    if (sizeInBytes < 1024) return '$sizeInBytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var size = sizeInBytes.toDouble();
    var index = -1;
    do {
      size /= 1024;
      index++;
    } while (size >= 1024 && index < units.length - 1);
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[index]}';
  }

  String get extension {
    final dot = title.lastIndexOf('.');
    return dot == -1 ? '' : title.substring(dot + 1).toUpperCase();
  }
}
