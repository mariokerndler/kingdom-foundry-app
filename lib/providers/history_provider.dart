import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/setup_result.dart';
import '../services/history_service.dart';
import 'config_provider.dart';

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(ref.watch(sharedPreferencesProvider)),
);

class HistoryState {
  final List<SetupResult> history;
  final List<SetupResult> favorites;

  const HistoryState({
    this.history = const [],
    this.favorites = const [],
  });

  bool isFavorite(SetupResult result) =>
      favorites.any((entry) => entry.storageKey == result.storageKey);
}

/// In-memory recent history plus locally saved presets.
final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>(
  (ref) => HistoryNotifier(ref.watch(historyServiceProvider)),
);

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super(_loadState(_service));

  static HistoryState _loadState(HistoryService service) => HistoryState(
        history: service.loadHistory(),
        favorites: service.loadFavorites(),
      );

  void _refresh() {
    state = _loadState(_service);
  }

  Future<void> push(SetupResult result) async {
    await _service.push(result);
    _refresh();
  }

  Future<void> toggleFavorite(SetupResult result) async {
    await _service.toggleFavorite(result);
    _refresh();
  }

  Future<void> removeFavorite(SetupResult result) async {
    await _service.removeFavorite(result);
    _refresh();
  }

  Future<void> clearHistory() async {
    await _service.clearHistory();
    state = HistoryState(favorites: state.favorites);
  }
}
