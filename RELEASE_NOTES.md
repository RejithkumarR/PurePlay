# PurePlay Release Notes

## Unreleased — Folder & File Management

### Added

- Folder-first browsing for local videos and audio.
- List and grid layouts for folders and media files.
- Sorting by file name.
- Sorting by date modified.
- Ascending and descending sort direction.
- Rename local media files.
- Copy local media files to another discovered folder.
- Move local media files to another discovered folder.
- Delete local media files with confirmation.
- MediaStore relative-path metadata for reliable folder grouping.
- PurePlay logo branding in the application header.

### Improved

- Replaced the flat media list with a two-level browsing experience: folders first, then files.
- File operations use Android MediaStore instead of relying on raw filesystem paths.
- UI actions use the existing PurePlay purple/cyan visual identity.
- README documentation now reflects the current MediaStore, folder browser, sorting, view modes, and file-management architecture.

### Android behavior

- Copy and move operations use MediaStore `RELATIVE_PATH` and require Android 10 or newer.
- Rename and delete operate directly on the MediaStore content URI.
- MediaStore remains the source of truth after operations; PurePlay rescans after each successful change.

### Notes

- Copy/move destinations are existing MediaStore-discovered folders.
- PurePlay does not request unrestricted filesystem access.
- The application remains offline-first; file management and playback do not require network connectivity.
