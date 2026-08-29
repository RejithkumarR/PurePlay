# PurePlay

PurePlay is an Android-first Flutter media player designed for **local files only**. It scans common shared-storage media folders and plays video/audio without an account, server, cloud connection, or streaming service.

## Included

- Local video and audio scanning
- MP4, MKV, AVI, MOV, WebM, FLV, WMV, 3GP, TS, M4V, MPEG/MPG, VOB
- MP3, AAC, FLAC, WAV, M4A, OGG, OPUS, WMA, AMR
- Video playback powered by media_kit
- Full-screen video controls
- Original / Fit / Enhanced display modes
- Audio player with seek and playback controls
- Favorites
- Search by file name/folder
- Pull-to-refresh/rescan
- Back button confirmation before closing/stopping playback
- Dark modern UI
- No network permission is requested

## Important quality note

The **Enhanced** video mode is a lightweight display-side enhancement/upscaling presentation. It can make lower-resolution video look somewhat sharper on a higher-resolution display, but it cannot reconstruct genuine missing HD detail.

Likewise, the current audio player intentionally does not claim to perform true recorded-noise removal. Actual noise reduction needs a dedicated DSP/AI pipeline. The architecture leaves room to add that later using native Android audio processing or an offline model.

## Android permissions

- Android 13+: `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO`
- Android 12 and below: `READ_EXTERNAL_STORAGE`
- Media playback/wake-lock permissions are kept out because this first version does not implement background audio service.

## Build

1. Install Flutter and Android Studio.
2. Open this folder in Android Studio/VS Code.
3. Run:

```bash
flutter pub get
flutter analyze
flutter run
```

Release APK:

```bash
flutter build apk --release
```

The APK will be under `build/app/outputs/flutter-apk/`.

## Recommended next version

For a stronger MX Player-style experience, the next iteration should add:

1. MediaStore-based scanning for Android scoped-storage compatibility and faster indexing.
2. Persistent playback position/resume.
3. Previous/next media queue.
4. Subtitle selection and external `.srt`/`.ass` support.
5. Audio equalizer and loudness enhancement through native Android audio effects.
6. True offline audio noise reduction using an optional on-device DSP/AI model.
7. Hardware decoder diagnostics and codec information.
8. Folder browser with a user-selected root instead of only common media folders.
9. Picture-in-picture mode.
10. Sleep timer, playback speed, repeat/shuffle, and screen-lock controls.
11. Thumbnail generation and media metadata.
12. Optional Android Auto/media notification integration.

## Package identity

App name: **PurePlay**
Application ID: `com.pureplay.localplayer`

This project is intentionally offline-first and does not include analytics, advertising, login, or network access.
