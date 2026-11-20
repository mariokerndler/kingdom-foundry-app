import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/heuristic_engine.dart';
import '../controllers/setup_engine.dart';
import '../models/kingdom_card.dart';
import '../models/setup_result.dart';

const _kHistory = 'kingdom_history';
const _kFavorites = 'kingdom_favorites';
const _maxHistory = 10;

String encodeKingdomBackup(List<SetupResult> kingdoms) => jsonEncode({
      'version': 1,
      'kingdoms':
          kingdoms.map((result) => result.toJson(compact: true)).toList(),
    });

List<SetupResult> decodeKingdomBackup(
    String text, List<KingdomCard> catalogue) {
  final json = jsonDecode(text);
  if (json is! Map<String, dynamic> ||
      json['version'] != 1 ||
      json['kingdoms'] is! List) {
    throw const FormatException(
        'Expected a Kingdom Foundry backup, version 1.');
  }
  final byId = {for (final card in catalogue) card.id: card};
  final engine = HeuristicEngine();
  return (json['kingdoms'] as List).map((entry) {
    if (entry is! Map<String, dynamic> || entry['kingdomCardIds'] is! List) {
      throw const FormatException('The backup contains an invalid board.');
    }
    try {
      final result = SetupResult.fromJson(entry, catalogue: byId);
      validateImportedKingdom(catalogue, result.kingdomCards,
          landscapes: result.landscapeCards);
      if (!result.kingdomSlotIds.containsAll(result.lockedSlotIds) ||
          !result.landscapeCards
              .map((card) => card.id)
              .toSet()
              .containsAll(result.lockedLandscapeIds)) {
        throw const FormatException(
            'The backup contains locks for cards outside a board.');
      }
      if (result.setupChoices.isNotEmpty) {
        SetupEngine().completeTableSetup(result, catalogue,
            previous: result.setupChoices, validatePrevious: true);
      }
      return engine.enrich(result);
    } on TypeError {
      throw const FormatException('The backup contains an invalid board.');
    }
  }).toList();
}

/// Persists the last [_maxHistory] generated kingdoms and saved favorites.
class HistoryService {
  final SharedPreferences _prefs;
  final Future<List<KingdomCard>> Function()? loadCatalogue;
  final _saved = <String, List<SetupResult>>{};
  final _unavailableBoards = <String, List<Map<String, dynamic>>>{};
  Future<void>? _catalogueLoad;
  Map<String, KingdomCard>? _catalogue;
  String? _catalogueRevision;
  Future<void> _pendingWrite = Future.value();
  bool hadUnreadableEntries = false;

  HistoryService(this._prefs, {this.loadCatalogue});

  bool get needsCatalogue =>
      _catalogue == null &&
      [_kHistory, _kFavorites].any(
        (key) => switch (_prefs.get(key)) {
          String stored => stored.contains('"kingdomCardIds":'),
          _ => false,
        },
      );

  Future<void> prepare() async {
    if (needsCatalogue) await _loadCardLookup();
  }

  Future<void> _loadCardLookup() async {
    if (_catalogue != null) return;
    final load = loadCatalogue;
    if (load == null) throw StateError('Card catalogue is unavailable.');
    final pending = _catalogueLoad ??= load().then((cards) {
      final encoded = jsonEncode(cards.map((card) => card.toJson()).toList());
      // Use integer arithmetic that stays exact on both Dart VM and web.
      var checksum = 0;
      for (final unit in encoded.codeUnits) {
        checksum = (checksum * 31 + unit) % 4294967291;
      }
      _catalogueRevision = 'v1-${checksum.toRadixString(16).padLeft(8, '0')}';
      _catalogue = {for (final card in cards) card.id: card};
    });
    try {
      await pending;
    } finally {
      if (identical(_catalogueLoad, pending)) _catalogueLoad = null;
    }
  }

  List<SetupResult> loadHistory() => _loadList(_kHistory);

  Future<List<SetupResult>> loadCommittedHistory() async {
    await _pendingWrite;
    await prepare();
    return loadHistory();
  }

  List<SetupResult> loadFavorites() {
    final keys = <String>{};
    return _loadList(_kFavorites)
        .where((result) => keys.add(result.selectionKey))
        .toList();
  }

  List<SetupResult> _loadList(String key) {
    if (needsCatalogue) {
      throw StateError('Prepare the library before loading it.');
    }
    return List.of(_saved.putIfAbsent(key, () => _readList(key)));
  }

  List<SetupResult> _readList(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      final recovered = <SetupResult>[];
      for (final entry in list) {
        try {
          final json = entry as Map<String, dynamic>;
          final result = SetupResult.fromJson(json, catalogue: _catalogue);
          if (json.containsKey('kingdomCardIds')) {
            validateImportedKingdom(_catalogue!.values, result.kingdomCards,
                landscapes: result.landscapeCards);
            if (result.setupChoices.isNotEmpty) {
              SetupEngine().completeTableSetup(
                  result, _catalogue!.values.toList(),
                  previous: result.setupChoices, validatePrevious: true);
            }
            recovered.add(HeuristicEngine().enrich(result));
          } else {
            recovered.add(result);
          }
        } on FormatException {
          if (entry is Map<String, dynamic> &&
              entry.containsKey('kingdomCardIds')) {
            (_unavailableBoards[key] ??= []).add(entry);
          }
          hadUnreadableEntries = true;
        } catch (_) {
          hadUnreadableEntries = true;
        }
      }
      return recovered;
    } catch (_) {
      hadUnreadableEntries = true;
      return [];
    }
  }

  Future<void> push(SetupResult result) => _write(() {
        final history = loadHistory();
        history.insert(0, result);
        return _saveList(_kHistory, history.take(_maxHistory).toList());
      });

  Future<void> toggleFavorite(SetupResult result) => _write(() {
        final favorites = loadFavorites();
        final index = favorites
            .indexWhere((entry) => entry.selectionKey == result.selectionKey);

        if (index >= 0) {
          favorites.removeAt(index);
        } else {
          favorites.insert(0, result);
        }

        return _saveList(_kFavorites, favorites);
      });

  Future<void> removeFavorite(SetupResult result) => _write(() => _saveList(
      _kFavorites,
      loadFavorites()
        ..removeWhere((entry) => entry.selectionKey == result.selectionKey)));

  Future<void> editFavorite(SetupResult result, String name, String notes) =>
      _write(() {
        final favorites = loadFavorites();
        final index = favorites
            .indexWhere((entry) => entry.selectionKey == result.selectionKey);
        if (index == -1) throw StateError('Saved kingdom no longer exists.');
        favorites[index] = favorites[index]
            .copyWith(savedName: name.trim(), savedNotes: notes.trim());
        return _saveList(_kFavorites, favorites);
      });

  Future<void> updateTableChoices(SetupResult result) => _write(() async {
        for (final key in [_kHistory, _kFavorites]) {
          final entries = key == _kHistory ? loadHistory() : loadFavorites();
          var changed = false;
          for (var i = 0; i < entries.length; i++) {
            final entry = entries[i];
            final matches = key == _kHistory
                ? entry.storageKey == result.storageKey
                : entry.selectionKey == result.selectionKey;
            if (matches &&
                (entry.platinumColonyChoice != result.platinumColonyChoice ||
                    entry.sheltersChoice != result.sheltersChoice)) {
              entries[i] = entry.copyWith(
                platinumColonyChoice: result.platinumColonyChoice,
                sheltersChoice: result.sheltersChoice,
              );
              changed = true;
            }
          }
          if (changed) await _saveList(key, entries);
        }
      });

  Future<void> mergeFavorites(List<SetupResult> incoming) => _write(() {
        final favorites = loadFavorites();
        final keys = favorites.map((entry) => entry.selectionKey).toSet();
        return _saveList(_kFavorites, [
          ...favorites,
          ...incoming.where((entry) => keys.add(entry.selectionKey)),
        ]);
      });

  Future<void> clearHistory() =>
      _write(() => _saveList(_kHistory, [], discardUnavailable: true));

  Future<void> restoreHistory(List<SetupResult> removed) => _write(() {
        final history = loadHistory();
        final keys = history.map((result) => result.storageKey).toSet();
        history.addAll(removed.where((result) => keys.add(result.storageKey)));
        return _saveList(_kHistory, history.take(_maxHistory).toList());
      });

  Future<void> _write(Future<void> Function() action) {
    final operation = _pendingWrite.then((_) async {
      await prepare();
      if (loadCatalogue != null && _catalogue == null) {
        try {
          await _loadCardLookup();
        } catch (_) {
          // A legacy library can still be saved as-is if the catalogue fails.
        }
      }
      await action();
    });
    _pendingWrite =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _saveList(String key, List<SetupResult> results,
      {bool discardUnavailable = false}) async {
    // SharedPreferences updates its cache before the platform write succeeds.
    // Keep mutations based on the last confirmed list.
    _saved.putIfAbsent(key, () => _readList(key));
    final saved = <SetupResult>[];
    final encoded = <Map<String, dynamic>>[];
    final catalogue = _catalogue;
    for (final result in results) {
      final compact = catalogue != null &&
          result.kingdomCards.every((card) => catalogue.containsKey(card.id)) &&
          result.landscapeCards.every((card) => catalogue.containsKey(card.id));
      final board = compact && result.catalogueRevision == null
          ? result.copyWith(catalogueRevision: _catalogueRevision)
          : result;
      saved.add(board);
      encoded.add(board.toJson(compact: compact));
    }
    final stored = await _prefs.setString(
      key,
      jsonEncode([
        ...encoded,
        if (!discardUnavailable) ...?_unavailableBoards[key],
      ]),
    );
    if (!stored) throw StateError('Kingdom library could not be saved.');
    _saved[key] = saved;
    if (discardUnavailable) _unavailableBoards.remove(key);
  }
}
