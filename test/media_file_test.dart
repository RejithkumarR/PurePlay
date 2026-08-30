import 'package:flutter_test/flutter_test.dart';

import 'package:pureplay/models/media_file.dart';

void main() {
  group('MediaFile', () {
    final modifiedDate = DateTime(2026, 8, 30);

    test('formats bytes correctly', () {
      expect(
        const MediaFile(
          path: '/storage/emulated/0/video.mp4',
          title: 'video.mp4',
          folderName: 'Movies',
          relativePath: 'Movies',
          sizeInBytes: 500,
          modifiedDate: modifiedDate,
          type: MediaType.video,
        ).formattedSize,
        '500 B',
      );

      expect(
        const MediaFile(
          path: '/storage/emulated/0/video.mp4',
          title: 'video.mp4',
          folderName: 'Movies',
          relativePath: 'Movies',
          sizeInBytes: 2048,
          modifiedDate: modifiedDate,
          type: MediaType.video,
        ).formattedSize,
        '2.0 KB',
      );
    });

    test('extracts and uppercases file extension', () {
      const media = MediaFile(
        path: '/storage/emulated/0/movie.mkv',
        title: 'movie.mkv',
        folderName: 'Movies',
        relativePath: 'Movies',
        sizeInBytes: 1024,
        modifiedDate: modifiedDate,
        type: MediaType.video,
      );

      expect(media.extension, 'MKV');
    });

    test('returns empty extension when title has no extension', () {
      const media = MediaFile(
        path: '/storage/emulated/0/recording',
        title: 'recording',
        folderName: 'Music',
        relativePath: 'Music',
        sizeInBytes: 1024,
        modifiedDate: modifiedDate,
        type: MediaType.audio,
      );

      expect(media.extension, '');
    });
  });
}
