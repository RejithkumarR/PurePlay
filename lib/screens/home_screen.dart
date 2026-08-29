import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/media_file.dart';
import '../services/media_scanner.dart';
import '../services/preferences_service.dart';
import '../utils/constants.dart';
import '../widgets/exit_dialog.dart';
import '../widgets/media_tile.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<MediaFile> _all = [];
  Set<String> _favorites = {};
  bool _loading = true;
  String _query = '';
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final granted = await MediaScanner.requestPermissions();
    if (!granted) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    final files = await MediaScanner.scanStorage();
    final favorites = await PreferencesService.favorites();
    if (mounted) {
      setState(() {
        _all = files;
        _favorites = favorites;
        _loading = false;
      });
    }
  }

  List<MediaFile> _filtered(MediaType type) {
    final q = _query.trim().toLowerCase();
    return _all.where((m) {
      if (m.type != type) return false;
      if (_showFavorites && !_favorites.contains(m.path)) return false;
      return q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.folderName.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleFavorite(MediaFile media) async {
    await PreferencesService.toggleFavorite(media.path);
    if (mounted) {
      setState(() => _favorites = {..._favorites}..toggle(media.path));
    }
  }

  Future<void> _exitApp() async {
    if (!mounted) return;
    final shouldExit = await confirmExit(context);
    if (shouldExit && mounted) {
      await SystemNavigator.pop();
    }
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
        if (!didPop) {
          await _exitApp();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.play_circle_fill_rounded, color: AppColors.accent),
            SizedBox(width: 8),
            Text('PurePlay', style: TextStyle(fontWeight: FontWeight.w800))
          ]),
          actions: [
            IconButton(
                tooltip: 'Favorites',
                icon: Icon(
                    _showFavorites ? Icons.favorite : Icons.favorite_border),
                onPressed: () =>
                    setState(() => _showFavorites = !_showFavorites)),
            IconButton(
                tooltip: 'Rescan',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load),
          ],
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(text: 'Videos', icon: Icon(Icons.video_library_rounded)),
            Tab(text: 'Audio', icon: Icon(Icons.library_music_rounded))
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search local media...',
                            border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => _query = v))),
                Expanded(
                    child: TabBarView(controller: _tabs, children: [
                  _mediaList(MediaType.video),
                  _mediaList(MediaType.audio)
                ])),
              ]),
      ),
    );
  }

  Widget _mediaList(MediaType type) {
    final items = _filtered(type);
    if (items.isEmpty) {
      return Center(
          child: Text(_showFavorites
              ? 'No favorite ${type.name} files'
              : 'No ${type.name} files found'));
    }
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (_, i) {
              final media = items[i];
              return MediaTile(
                  media: media,
                  favorite: _favorites.contains(media.path),
                  onFavorite: () => _toggleFavorite(media),
                  onTap: () async {
                    await PreferencesService.addRecent(media.path);
                    if (!mounted) return;
                    if (type == MediaType.video) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            media: media,
                            playlist: items,
                            initialIndex: i,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AudioPlayerScreen(media: media),
                        ),
                      );
                    }
                  });
            }));
  }
}

extension on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}
