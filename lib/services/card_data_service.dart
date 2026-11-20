import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/kingdom_card.dart';
import '../models/expansion.dart';

/// Loads, parses, and caches the card catalogue from assets/data/cards.json.
///
/// This is a pure data service — it owns no Flutter state.  Riverpod providers
/// in lib/providers/ expose it to the widget tree.
class CardDataService {
  static const _assetPath = 'assets/data/cards.json';

  // Lazily populated cache — null until first call to [loadAll].
  Future<List<KingdomCard>>? _cache;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns every card in the catalogue.
  /// Parses the JSON asset on first call; subsequent calls return the cache.
  Future<List<KingdomCard>> loadAll() {
    if (_cache != null) return _cache!;
    final pending = _load();
    _cache = pending;
    pending.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      if (identical(_cache, pending)) _cache = null;
    });
    return pending;
  }

  Future<List<KingdomCard>> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final parsed = json.decode(raw) as List<dynamic>;

    return parsed
        .map((e) => KingdomCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Returns all kingdom cards from the given [expansions].
  Future<List<KingdomCard>> forExpansions(Set<Expansion> expansions) async {
    final all = await loadAll();
    return all
        .where((c) =>
            expansions.contains(c.expansion) &&
            c.isKingdomCard &&
            !c.isAuxiliary)
        .toList();
  }

  /// Returns the set of expansions that have at least one card in the data.
  Future<Set<Expansion>> availableExpansions() async {
    final all = await loadAll();
    return all.map((c) => c.expansion).toSet();
  }

  /// Invalidates the cache (useful in tests or after hot-reload).
  void invalidate() => _cache = null;
}
