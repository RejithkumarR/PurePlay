import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_file.dart';
import '../utils/constants.dart';

class MediaScanner {
  static const MethodChannel _channel =
      MethodChannel(
    'com.pureplay.localplayer/media_scanner',
  );

  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final sdk =
        (await DeviceInfoPlugin().androidInfo).version.sdkInt;

    if (sdk >= 33) {
      final result = await [
        Permission.videos,
        Permission.audio,
      ].request();

      final videoGranted =
          result[Permission.videos]?.isGranted ?? false;

      final audioGranted =
          result[Permission.audio]?.isGranted ?? false;

      return videoGranted && audioGranted;
    }

    final status =
        await Permission.storage.request();

    return status.isGranted;
  }

  static Future<List<MediaFile>> scanStorage() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>(
        'scanMedia',
      );

      if (result == null || result.isEmpty) {
        return [];
      }

      final mediaFiles = <MediaFile>[];
      final seen = <String>{};

      for (final item in result) {
        if (item is! Map) {
          continue;
        }

        final map =
            Map<String, dynamic>.from(item);

        final path =
            map['path']?.toString() ?? '';

        final uri =
            map['uri']?.toString() ?? '';

        final title =
            map['title']?.toString() ??
                'Unknown';

        final folderName =
            map['folderName']?.toString() ??
                'Internal storage';

        final size =
            _toInt(map['size']);

        final modified =
            _toInt(map['modified']);

        final typeString =
            map['type']?.toString() ?? '';

        // IMPORTANT:
        // Prefer MediaStore URI on modern Android.
        final mediaPath =
            uri.isNotEmpty ? uri : path;

        if (mediaPath.isEmpty) {
          continue;
        }

        final uniqueKey =
            uri.isNotEmpty ? uri : mediaPath;

        if (!seen.add(uniqueKey)) {
          continue;
        }

        MediaType? type;

        if (typeString == 'video') {
          type = MediaType.video;
        } else if (typeString == 'audio') {
          type = MediaType.audio;
        }

        if (type == null) {
          continue;
        }

        mediaFiles.add(
          MediaFile(
            path: mediaPath,
            title: title,
            folderName: folderName,
            sizeInBytes: size,
            modifiedDate:
                modified > 0
                    ? DateTime
                        .fromMillisecondsSinceEpoch(
                            modified,
                          )
                    : DateTime.fromMillisecondsSinceEpoch(
                        0,
                      ),
            type: type,
          ),
        );
      }

      mediaFiles.sort(
        (a, b) => a.title
            .toLowerCase()
            .compareTo(
              b.title.toLowerCase(),
            ),
      );

      return mediaFiles;
    } on PlatformException catch (e) {
      print(
        'PurePlay MediaStore error: '
        '${e.code}: ${e.message}',
      );

      return [];
    } catch (e) {
      print(
        'PurePlay media scanner error: $e',
      );

      return [];
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}