import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _favoritesKey = 'favorites';
  static const _recentKey = 'recent';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<Set<String>> favorites() async {
    return (await _prefs).getStringList(_favoritesKey)?.toSet() ?? <String>{};
  }

  static Future<void> toggleFavorite(String path) async {
    final prefs = await _prefs;
    final values = prefs.getStringList(_favoritesKey)?.toSet() ?? <String>{};
    values.contains(path) ? values.remove(path) : values.add(path);
    await prefs.setStringList(_favoritesKey, values.toList());
  }

  static Future<List<String>> recent() async {
    return (await _prefs).getStringList(_recentKey) ?? <String>[];
  }

  static Future<void> addRecent(String path) async {
    final prefs = await _prefs;
    final values = prefs.getStringList(_recentKey) ?? <String>[];
    values.remove(path);
    values.insert(0, path);
    await prefs.setStringList(_recentKey, values.take(30).toList());
  }
}
