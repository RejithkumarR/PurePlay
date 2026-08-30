import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/media_file.dart';
import '../services/media_file_operations.dart';
import '../services/media_scanner.dart';
import '../services/preferences_service.dart';
import '../utils/constants.dart';
import '../widgets/exit_dialog.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

class _FolderEntry {
  const _FolderEntry({required this.path, required this.name, required this.files});
  final String path;
  final String name;
  final List<MediaFile> files;
}

enum _SortMode { name, date }
enum _ViewMode { list, grid }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<MediaFile> _all = [];
  Set<String> _favorites = {};
  bool _loading = true;
  String _query = '';
  bool _showFavorites = false;
  _SortMode _sortMode = _SortMode.name;
  bool _ascending = true;
  _ViewMode _viewMode = _ViewMode.grid;
  String? _openFolderPath;

  MediaType get _currentType => _tabs.index == 0 ? MediaType.video : MediaType.audio;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final granted = await MediaScanner.requestPermissions();
    if (!granted) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final files = await MediaScanner.scanStorage();
    final favorites = await PreferencesService.favorites();
    if (!mounted) return;
    setState(() {
      _all = files;
      _favorites = favorites;
      _loading = false;
      if (_openFolderPath != null && !_foldersFor(_currentType).any((f) => f.path == _openFolderPath)) {
        _openFolderPath = null;
      }
    });
  }

  List<MediaFile> _filtered(MediaType type) {
    final query = _query.trim().toLowerCase();
    return _all.where((media) {
      if (media.type != type) return false;
      if (_showFavorites && !_favorites.contains(media.path)) return false;
      return query.isEmpty ||
          media.title.toLowerCase().contains(query) ||
          media.folderName.toLowerCase().contains(query) ||
          media.relativePath.toLowerCase().contains(query);
    }).toList();
  }

  List<_FolderEntry> _foldersFor(MediaType type) {
    final grouped = <String, List<MediaFile>>{};
    for (final media in _filtered(type)) {
      final key = media.relativePath.isNotEmpty ? media.relativePath : media.folderName;
      grouped.putIfAbsent(key, () => []).add(media);
    }
    final folders = grouped.entries
        .map((entry) => _FolderEntry(path: entry.key, name: _displayFolderName(entry.key), files: entry.value))
        .toList();
    folders.sort((a, b) => _compareText(a.name, b.name));
    return _ascending ? folders : folders.reversed.toList();
  }

  String _displayFolderName(String path) {
    final clean = path.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    if (clean.isEmpty) return 'Internal storage';
    return clean.split('/').lastWhere((part) => part.isNotEmpty, orElse: () => 'Internal storage');
  }

  int _compareText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  List<MediaFile> _sortedFiles(List<MediaFile> files) {
    final result = [...files];
    result.sort((a, b) {
      final comparison = _sortMode == _SortMode.name ? _compareText(a.title, b.title) : a.modifiedDate.compareTo(b.modifiedDate);
      return _ascending ? comparison : -comparison;
    });
    return result;
  }

  Future<void> _openMedia(List<MediaFile> items, int index) async {
    final media = items[index];
    await PreferencesService.addRecent(media.path);
    if (!mounted) return;
    if (media.type == MediaType.video) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(media: media, playlist: items, initialIndex: index),
        ),
      );
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AudioPlayerScreen(media: media)));
    }
  }

  Future<void> _rename(MediaFile media) async {
    final controller = TextEditingController(text: media.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'File name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == media.title) return;
    try {
      await MediaFileOperations.rename(uri: media.path, name: name);
      await _load();
      _toast('File renamed');
    } catch (e) {
      _toast('Rename failed: $e');
    }
  }

  Future<void> _delete(MediaFile media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${media.title}" from the device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await MediaFileOperations.delete(media.path);
      await _load();
      _toast('File deleted');
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  Future<void> _copyOrMove(MediaFile media, {required bool move}) async {
    final folders = _foldersFor(media.type).where((folder) => folder.path != media.relativePath).toList();
    if (folders.isEmpty) {
      _toast('No other destination folders found');
      return;
    }
    final destination = await showModalBottomSheet<_FolderEntry>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(move ? 'Move to folder' : 'Copy to folder', style: Theme.of(context).textTheme.titleLarge),
            ),
            ...folders.map(
              (folder) => ListTile(
                leading: Icon(Icons.folder_rounded, color: AppColors.accent),
                title: Text(folder.name),
                subtitle: Text(folder.path),
                onTap: () => Navigator.pop(context, folder),
              ),
            ),
          ],
        ),
      ),
    );
    if (destination == null) return;
    try {
      if (move) {
        await MediaFileOperations.move(uri: media.path, relativePath: destination.path);
      } else {
        await MediaFileOperations.copy(uri: media.path, relativePath: destination.path);
      }
      await _load();
      _toast(move ? 'File moved' : 'File copied');
    } catch (e) {
      _toast('${move ? 'Move' : 'Copy'} failed: $e');
    }
  }

  Future<void> _fileMenu(MediaFile media) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.drive_file_rename_outline), title: const Text('Rename'), onTap: () { Navigator.pop(context); _rename(media); }),
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy'), onTap: () { Navigator.pop(context); _copyOrMove(media, move: false); }),
            ListTile(leading: const Icon(Icons.drive_file_move_rounded), title: const Text('Move'), onTap: () { Navigator.pop(context); _copyOrMove(media, move: true); }),
            ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Delete'), onTap: () { Navigator.pop(context); _delete(media); }),
          ],
        ),
      ),
    );
  }

  Future<void> _showSortSheet() async {
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold))),
            RadioListTile<_SortMode>(value: _SortMode.name, groupValue: _sortMode, title: const Text('Name'), onChanged: (value) => Navigator.pop(context, {'mode': value, 'ascending': _ascending})),
            RadioListTile<_SortMode>(value: _SortMode.date, groupValue: _sortMode, title: const Text('Date modified'), onChanged: (value) => Navigator.pop(context, {'mode': value, 'ascending': _ascending})),
            SwitchListTile(title: const Text('Ascending'), value: _ascending, onChanged: (value) => Navigator.pop(context, {'mode': _sortMode, 'ascending': value})),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() {
        _sortMode = choice['mode'] as _SortMode;
        _ascending = choice['ascending'] as bool;
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _folderCard(_FolderEntry folder) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _openFolderPath = folder.path),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_rounded, size: 54, color: AppColors.accent),
                const SizedBox(height: 10),
                Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${folder.files.length} ${folder.files.length == 1 ? 'file' : 'files'}', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
      );

  Widget _folderListTile(_FolderEntry folder) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: CircleAvatar(backgroundColor: AppColors.surface2, child: Icon(Icons.folder_rounded, color: AppColors.accent)),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${folder.files.length} files • ${folder.path}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => setState(() => _openFolderPath = folder.path),
      );

  Widget _fileCard(List<MediaFile> items, int index) {
    final media = items[index];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMedia(items, index),
        onLongPress: () => _fileMenu(media),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Icon(media.type == MediaType.video ? Icons.movie_rounded : Icons.music_note_rounded, size: 52, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(iconSize: 20, visualDensity: VisualDensity.compact, onPressed: () => _fileMenu(media), icon: const Icon(Icons.more_vert_rounded)),
                ],
              ),
              Text('${media.formattedSize} • ${DateFormat('dd MMM yyyy').format(media.modifiedDate)}', style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileListTile(List<MediaFile> items, int index) {
    final media = items[index];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(backgroundColor: AppColors.surface2, child: Icon(media.type == MediaType.video ? Icons.movie_rounded : Icons.music_note_rounded, color: AppColors.accent)),
      title: Text(media.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${media.formattedSize} • ${DateFormat('dd MMM yyyy').format(media.modifiedDate)}'),
      trailing: IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () => _fileMenu(media)),
      onTap: () => _openMedia(items, index),
      onLongPress: () => _fileMenu(media),
    );
  }

  Widget _fileView(List<MediaFile> items) {
    if (items.isEmpty) return const Center(child: Text('No files in this folder'));
    return RefreshIndicator(
      onRefresh: _load,
      child: _viewMode == _ViewMode.grid
          ? GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 210, childAspectRatio: .92, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: items.length,
              itemBuilder: (_, index) => _fileCard(items, index),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, index) => _fileListTile(items, index),
            ),
    );
  }

  Widget _content(MediaType type) {
    if (_openFolderPath != null) {
      final matching = _foldersFor(type).where((folder) => folder.path == _openFolderPath);
      final folder = matching.isEmpty ? null : matching.first;
      if (folder == null) return const Center(child: Text('Folder is no longer available'));
      return _fileView(_sortedFiles(folder.files));
    }

    final folders = _foldersFor(type);
    if (folders.isEmpty) {
      return Center(child: Text(_showFavorites ? 'No favorite ${type.name} files' : 'No ${type.name} files found'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _viewMode == _ViewMode.grid
          ? GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, childAspectRatio: 1.12, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: folders.length,
              itemBuilder: (_, index) => _folderCard(folders[index]),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, index) => _folderListTile(folders[index]),
            ),
    );
  }

  Future<void> _exitApp() async {
    if (!mounted) return;
    final shouldExit = await confirmExit(context);
    if (shouldExit && mounted) await SystemNavigator.pop();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_openFolderPath != null) {
          setState(() => _openFolderPath = null);
        } else {
          await _exitApp();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _openFolderPath != null
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _openFolderPath = null))
              : null,
          title: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/logo.png', width: 34, height: 34, fit: BoxFit.cover)),
              const SizedBox(width: 10),
              const Text('PurePlay', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(tooltip: 'View', icon: Icon(_viewMode == _ViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded), onPressed: () => setState(() => _viewMode = _viewMode == _ViewMode.grid ? _ViewMode.list : _ViewMode.grid)),
            IconButton(tooltip: 'Sort', icon: const Icon(Icons.sort_rounded), onPressed: _showSortSheet),
            IconButton(tooltip: 'Favorites', icon: Icon(_showFavorites ? Icons.favorite : Icons.favorite_border), onPressed: () => setState(() { _showFavorites = !_showFavorites; _openFolderPath = null; })),
            IconButton(tooltip: 'Rescan', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          ],
          bottom: TabBar(
            controller: _tabs,
            onTap: (_) => setState(() => _openFolderPath = null),
            tabs: const [
              Tab(text: 'Videos', icon: Icon(Icons.video_library_rounded)),
              Tab(text: 'Audio', icon: Icon(Icons.library_music_rounded)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search local media...', border: OutlineInputBorder()),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Expanded(child: TabBarView(controller: _tabs, children: [_content(MediaType.video), _content(MediaType.audio)])),
                ],
              ),
      ),
    );
  }
}
