import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/setup_result.dart';
import '../services/history_service.dart';
import 'card_data_providers.dart';
import 'config_provider.dart';

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(ref.watch(sharedPreferencesProvider),
      loadCatalogue: () => ref.read(allCardsProvider.future)),
);

class HistoryState {
  final List<SetupResult> history;
  final List<SetupResult> favorites;
  final bool hadUnreadableEntries;
  final bool isLoading;
  final bool couldNotLoad;

  const HistoryState({
    this.history = const [],
    this.favorites = const [],
    this.hadUnreadableEntries = false,
    this.isLoading = false,
    this.couldNotLoad = false,
  });

  bool isFavorite(SetupResult result) =>
      favorites.any((entry) => entry.selectionKey == result.selectionKey);
}

/// In-memory recent history plus locally saved presets.
final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>(
  (ref) => HistoryNotifier(ref.watch(historyServiceProvider),
      onSaveFailure: (message) {
    ref.read(storageNoticeProvider.notifier).state =
        (message: message, retry: null);
  }),
);

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryService _service;
  final void Function(String message)? onSaveFailure;

  HistoryNotifier(this._service, {this.onSaveFailure})
      : super(_service.needsCatalogue
            ? const HistoryState(isLoading: true)
            : _loadState(_service)) {
    if (state.isLoading) _loadLibrary();
  }

  void reload() {
    state = const HistoryState(isLoading: true);
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      await _service.prepare();
      if (mounted) state = _loadState(_service);
    } catch (_) {
      if (mounted) state = const HistoryState(couldNotLoad: true);
    }
  }

  static HistoryState _loadState(HistoryService service) => HistoryState(
        history: service.loadHistory(),
        favorites: service.loadFavorites(),
        hadUnreadableEntries: service.hadUnreadableEntries,
      );

  Future<bool> push(SetupResult result) => _persist(() => _service.push(result),
      'The board could not be added to recent history.');

  Future<bool> toggleFavorite(SetupResult result) => _persist(
      () => _service.toggleFavorite(result),
      'The saved kingdoms could not be updated.');

  Future<bool> removeFavorite(SetupResult result) => _persist(
      () => _service.removeFavorite(result),
      'The saved kingdom could not be removed.');

  Future<bool> editFavorite(SetupResult result, String name, String notes) =>
      _persist(() => _service.editFavorite(result, name, notes),
          'The name and notes could not be saved.');

  Future<bool> updateTableChoices(SetupResult result) => _persist(
      () => _service.updateTableChoices(result),
      'The table setup choices could not be saved.');

  Future<bool> mergeFavorites(List<SetupResult> incoming) => _persist(
      () => _service.mergeFavorites(incoming),
      'The backup could not be saved.');

  Future<bool> clearHistory() =>
      _persist(_service.clearHistory, 'Recent history could not be cleared.');

  Future<bool> restoreHistory(List<SetupResult> history) => _persist(
      () => _service.restoreHistory(history),
      'Recent history could not be restored.');

  Future<bool> _persist(Future<void> Function() action, String message) async {
    try {
      await action();
      if (mounted) state = _loadState(_service);
      return true;
    } catch (_) {
      if (mounted) onSaveFailure?.call(message);
      return false;
    }
  }
}
