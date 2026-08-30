import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_file.dart';

class MediaScanner {
  static const MethodChannel _channel =
      MethodChannel('com.pureplay.localplayer/media_scanner');

  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) {
      final result = await [Permission.videos, Permission.audio].request();
      return (result[Permission.videos]?.isGranted ?? false) &&
          (result[Permission.audio]?.isGranted ?? false);
    }
    return (await Permission.storage.request()).isGranted;
  }

  static Future<List<MediaFile>> scanStorage() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('scanMedia');
      if (result == null || result.isEmpty) return [];
      final mediaFiles = <MediaFile>[];
      final seen = <String>{};

      for (final item in result) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final path = map['path']?.toString() ?? '';
        final uri = map['uri']?.toString() ?? '';
        final mediaPath = uri.isNotEmpty ? uri : path;
        if (mediaPath.isEmpty) continue;
        final uniqueKey = uri.isNotEmpty ? uri : mediaPath;
        if (!seen.add(uniqueKey)) continue;

        final typeString = map['type']?.toString() ?? '';
        final MediaType? type = typeString == 'video'
            ? MediaType.video
            : typeString == 'audio'
                ? MediaType.audio
                : null;
        if (type == null) continue;

        final relativePath = map['relativePath']?.toString() ?? '';
        final folderName = map['folderName']?.toString() ?? 'Internal storage';
        final modified = _toInt(map['modified']);

        mediaFiles.add(
          MediaFile(
            path: mediaPath,
            title: map['title']?.toString() ?? 'Unknown',
            folderName: folderName,
            relativePath: relativePath,
            sizeInBytes: _toInt(map['size']),
            modifiedDate: modified > 0
                ? DateTime.fromMillisecondsSinceEpoch(modified)
                : DateTime.fromMillisecondsSinceEpoch(0),
            type: type,
          ),
        );
      }

      return mediaFiles;
    } on PlatformException catch (e) {
      debugPrint('PurePlay MediaStore error: ${e.code}: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('PurePlay media scanner error: $e');
      return [];
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
