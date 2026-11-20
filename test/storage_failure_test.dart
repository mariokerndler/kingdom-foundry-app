import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/table_setup_choice.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/history_provider.dart';
import 'package:kingdom_foundry/services/config_persistence_service.dart';
import 'package:kingdom_foundry/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RejectingPreferences implements SharedPreferences {
  final saved = <String, String>{};
  final cache = <String, String>{};
  bool rejectNext = false;

  @override
  Object? get(String key) => cache[key];

  @override
  String? getString(String key) => cache[key];

  @override
  Future<bool> setString(String key, String value) async {
    cache[key] = value;
    if (rejectNext) {
      rejectNext = false;
      return false;
    }
    saved[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SetupResult _result(int minute) => SetupResult(
      kingdomCards: [
        KingdomCard(
            id: 'card_$minute',
            name: 'Card $minute',
            expansion: Expansion.baseSecondEdition,
            types: [CardType.action],
            tags: [],
            cost: 3,
            text: '')
      ],
      archetypes: [],
      setupNotes: [],
      generatedAt: DateTime(2026, 1, 1, 0, minute),
    );

void main() {
  test('failed settings save offers retry for the current settings', () async {
    final prefs = _RejectingPreferences()..rejectNext = true;
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    container.read(configProvider.notifier).setPlayerCount(4);
    await Future<void>.delayed(Duration.zero);
    final notice = container.read(storageNoticeProvider)!;
    expect(notice.message, contains('could not be saved'));
    expect(prefs.saved, isEmpty);
    expect(container.read(configProvider).playerCount, 4);

    notice.retry!();
    await Future<void>.delayed(Duration.zero);
    final restarted = _RejectingPreferences()..cache.addAll(prefs.saved);
    expect(ConfigPersistenceService(restarted).load().playerCount, 4);
  });

  test('failed favorites writes do not affect queued successful writes',
      () async {
    final prefs = _RejectingPreferences()..rejectNext = true;
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final history = container.read(historyProvider.notifier);
    final boards = [_result(0), _result(1), _result(2)];
    final results = await Future.wait(boards.map(history.toggleFavorite));

    expect(results, [false, true, true]);
    expect(container.read(storageNoticeProvider)?.message,
        contains('could not be updated'));
    expect(container.read(historyProvider).favorites, [boards[2], boards[1]]);
    final restarted = _RejectingPreferences()..cache.addAll(prefs.saved);
    expect(HistoryService(restarted).loadFavorites().map((r) => r.storageKey),
        [boards[2].storageKey, boards[1].storageKey]);
  });

  test('undo clearing history keeps boards generated after the clear',
      () async {
    final service = HistoryService(_RejectingPreferences());
    final earlier = _result(0);
    final later = _result(1);
    await service.push(earlier);
    final removed = service.loadHistory();
    await service.clearHistory();
    await service.push(later);
    await service.restoreHistory(removed);
    expect(service.loadHistory(), [later, earlier]);
  });

  test('failed table-choice saves report failure and can be retried', () async {
    final prefs = _RejectingPreferences();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final library = container.read(historyProvider.notifier);
    final board = _result(0);
    await library.push(board);
    await library.toggleFavorite(board);
    final chosen = board.copyWith(sheltersChoice: TableSetupChoice.include);
    prefs.rejectNext = true;
    expect(await library.updateTableChoices(chosen), isFalse);
    expect(container.read(storageNoticeProvider)?.message,
        contains('table setup choices could not be saved'));
    expect(container.read(historyProvider).history.single.sheltersChoice,
        TableSetupChoice.undecided);
    expect(await library.updateTableChoices(chosen), isTrue);
    final restarted = _RejectingPreferences()..cache.addAll(prefs.saved);
    final saved = HistoryService(restarted);
    expect(saved.loadHistory().single.sheltersChoice, TableSetupChoice.include);
    expect(
        saved.loadFavorites().single.sheltersChoice, TableSetupChoice.include);
  });
}
