import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/setup_result.dart';

const _kHistory = 'kingdom_history';
const _kFavorites = 'kingdom_favorites';
const _maxHistory = 10;

/// Persists the last [_maxHistory] generated kingdoms.
class HistoryService {
  final SharedPreferences _prefs;
  HistoryService(this._prefs);

  List<SetupResult> loadHistory() => _loadList(_kHistory);

  List<SetupResult> loadFavorites() => _loadList(_kFavorites);

  List<SetupResult> _loadList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SetupResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> push(SetupResult result) async {
    final history = loadHistory();
    history.insert(0, result);
    final trimmed = history.take(_maxHistory).toList();
    await _saveList(_kHistory, trimmed);
  }

  Future<void> toggleFavorite(SetupResult result) async {
    final favorites = loadFavorites();
    final index =
        favorites.indexWhere((entry) => entry.storageKey == result.storageKey);

    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.insert(0, result);
    }

    await _saveList(_kFavorites, favorites);
  }

  Future<void> removeFavorite(SetupResult result) async {
    final favorites = loadFavorites()
      ..removeWhere((entry) => entry.storageKey == result.storageKey);
    await _saveList(_kFavorites, favorites);
  }

  Future<void> clearHistory() => _prefs.remove(_kHistory);

  Future<void> _saveList(String key, List<SetupResult> results) {
    return _prefs.setString(
      key,
      jsonEncode(results.map((r) => r.toJson()).toList()),
    );
  }
}
