import 'package:flutter/services.dart';

class MediaFileOperations {
  static const MethodChannel _channel =
      MethodChannel('com.pureplay.localplayer/media_scanner');

  static Future<void> rename({required String uri, required String name}) async {
    await _channel.invokeMethod<bool>('renameMedia', {
      'uri': uri,
      'name': name,
    });
  }

  static Future<void> delete(String uri) async {
    await _channel.invokeMethod<bool>('deleteMedia', {'uri': uri});
  }

  static Future<void> move({
    required String uri,
    required String relativePath,
  }) async {
    await _channel.invokeMethod<bool>('moveMedia', {
      'uri': uri,
      'relativePath': relativePath,
    });
  }

  static Future<void> copy({
    required String uri,
    required String relativePath,
    String? name,
  }) async {
    await _channel.invokeMethod<bool>('copyMedia', {
      'uri': uri,
      'relativePath': relativePath,
      if (name != null) 'name': name,
    });
  }
}
