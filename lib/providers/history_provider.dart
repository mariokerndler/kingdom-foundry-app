import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/setup_result.dart';
import '../services/history_service.dart';
import 'config_provider.dart';

final historyServiceProvider = Provider<HistoryService>(
  (ref) => HistoryService(ref.watch(sharedPreferencesProvider)),
);

/// In-memory list of past kingdoms, newest first.
/// Loaded once from prefs; updated after every successful generation.
final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<SetupResult>>(
  (ref) => HistoryNotifier(ref.watch(historyServiceProvider)),
);

class HistoryNotifier extends StateNotifier<List<SetupResult>> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super(_service.load());

  Future<void> push(SetupResult result) async {
    await _service.push(result);
    state = _service.load();
  }

  Future<void> clear() async {
    await _service.clear();
    state = [];
  }
}
