import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/setup_result.dart';

const _kHistory    = 'kingdom_history';
const _maxHistory  = 10;

/// Persists the last [_maxHistory] generated kingdoms.
class HistoryService {
  final SharedPreferences _prefs;
  HistoryService(this._prefs);

  List<SetupResult> load() {
    final raw = _prefs.getString(_kHistory);
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
    final history = load();
    history.insert(0, result);
    final trimmed = history.take(_maxHistory).toList();
    await _prefs.setString(
      _kHistory,
      jsonEncode(trimmed.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> clear() => _prefs.remove(_kHistory);
}
