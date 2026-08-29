import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_file.dart';
import '../utils/constants.dart';

class MediaScanner {
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      final result = await [Permission.videos, Permission.audio].request();
      return result.values.every((status) => status.isGranted);
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<List<MediaFile>> scanStorage() async {
    final results = <MediaFile>[];
    final roots = <Directory>[
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Movies'),
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/DCIM'),
      Directory('/storage/emulated/0/Pictures'),
      Directory('/storage/emulated/0/Recordings'),
      Directory('/storage/emulated/0/Video'),
      Directory('/storage/emulated/0/Audio'),
    ];

    final seen = <String>{};
    for (final root in roots) {
      if (!await root.exists()) continue;
      try {
        await for (final entity
            in root.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final lower = entity.path.toLowerCase();
          final dot = lower.lastIndexOf('.');
          if (dot < 0) continue;
          final ext = lower.substring(dot + 1);
          final type = SupportedFormats.video.contains(ext)
              ? MediaType.video
              : SupportedFormats.audio.contains(ext)
                  ? MediaType.audio
                  : null;
          if (type == null || !seen.add(lower)) continue;
          try {
            final stat = await entity.stat();
            final title = entity.uri.pathSegments.isNotEmpty
                ? entity.uri.pathSegments.last
                : entity.path;
            final parent =
                entity.parent.path.split(Platform.pathSeparator).last;
            results.add(MediaFile(
              path: entity.path,
              title: title,
              folderName: parent.isEmpty ? 'Internal storage' : parent,
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
              type: type,
            ));
          } catch (_) {}
        }
      } catch (_) {}
    }

    results
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return results;
  }
}
