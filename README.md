# PurePlay

PurePlay is an Android-first Flutter media player designed for **local files only**. It provides a clean, offline-first experience for browsing and playing video and audio stored on the device.

## Current features

- Android MediaStore-based local video and audio scanning
- Folder-first media browser instead of a flat media list
- Folder and file **list / grid** views
- Sort by **name** or **date modified**, ascending or descending
- Local file operations: **rename, copy, move and delete**
- Video playback powered by media_kit
- Previous / next video navigation
- 10-second forward and backward seeking
- Original / Fit / Enhanced display modes
- Audio player with seek and playback controls
- Favorites
- Search by file name and folder path
- Pull-to-refresh/rescan
- Android back navigation with clean folder/player navigation
- PurePlay logo and purple/cyan visual identity throughout the application
- No account, cloud service, streaming service, advertising, or analytics

## Folder browser

PurePlay reads media through Android MediaStore and groups discovered media by its indexed relative storage path. The Videos and Audio tabs open at the folder level first. Opening a folder shows only the media belonging to that folder.

Each browser level supports:

- List view
- Grid view
- Name sorting
- Date-modified sorting
- Ascending / descending order

## File operations

From a media file's action menu you can:

- **Rename** — change the MediaStore display name
- **Copy** — copy media to another discovered MediaStore folder
- **Move** — move media to another discovered MediaStore folder
- **Delete** — remove the media item from the device after confirmation

These operations use Android MediaStore APIs rather than relying on raw filesystem paths, which is better aligned with modern Android scoped-storage behavior.

Copy and move destinations are selected from folders currently discovered by PurePlay. Android 10+ is required for MediaStore relative-path copy/move operations.

## Supported formats

### Video

MP4, MKV, AVI, MOV, WebM, FLV, WMV, 3GP, TS, M4V, MPEG/MPG and VOB.

### Audio

MP3, AAC, FLAC, WAV, M4A, OGG, OPUS, WMA and AMR.

## Visual identity

The application uses `assets/logo.png` as the PurePlay application branding and launcher icon. The UI uses the PurePlay color palette:

- Primary: `#7C4DFF`
- Accent: `#00D4FF`
- Background: `#090A0F`
- Surface: `#151720`
- Secondary surface: `#20232D`

## Quality note

The **Enhanced** video mode is a lightweight display-side enhancement/upscaling presentation. It can make lower-resolution video look somewhat sharper on a higher-resolution display, but it cannot reconstruct genuine missing HD detail.

The current audio player does not claim to perform true recorded-noise removal. Actual noise reduction requires a dedicated DSP or offline AI processing pipeline.

## Android permissions

- Android 13+: `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO`
- Android 12 and below: `READ_EXTERNAL_STORAGE`
- Network access is not used for media discovery or playback.

## Build

Install Flutter and Android Studio, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Release APK:

```bash
flutter build apk --release
```

Play Store App Bundle:

```bash
flutter build appbundle --release
```

Debug APK:

```bash
flutter build apk --debug
```

## Architecture

```text
Flutter UI
   |
   +-- Home / Folder Browser
   |      +-- List / Grid
   |      +-- Search
   |      +-- Sorting
   |      +-- File Operations
   |
   +-- Video Player
   +-- Audio Player
   |
   +-- MediaScanner
          |
          | MethodChannel
          v
   Android MediaScannerPlugin
          |
          v
      Android MediaStore
          |
      +--- Video collection
      +--- Audio collection
          |
          v
      media_kit playback
```

## CI/CD

GitHub Actions validates Flutter analysis and release builds. The `develop` branch additionally produces a debug APK as a workflow artifact for device testing.

The development workflow is intentionally Pull Request based: changes are reviewed before merging into protected branches.

## Package identity

App name: **PurePlay**  
Application ID: `com.pureplay.localplayer`

This project is intentionally offline-first and does not include analytics, advertising, login, cloud synchronization, or streaming services.
