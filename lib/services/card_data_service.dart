import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dominion_card.dart';
import '../models/expansion.dart';

/// Loads, parses, and caches the card catalogue from assets/data/cards.json.
///
/// This is a pure data service — it owns no Flutter state.  Riverpod providers
/// in lib/providers/ expose it to the widget tree.
class CardDataService {
  static const _assetPath = 'assets/data/cards.json';

  // Lazily populated cache — null until first call to [loadAll].
  List<DominionCard>? _cache;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns every card in the catalogue.
  /// Parses the JSON asset on first call; subsequent calls return the cache.
  Future<List<DominionCard>> loadAll() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final parsed = json.decode(raw) as List<dynamic>;

    _cache = parsed
        .map((e) => DominionCard.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    return _cache!;
  }

  /// Returns all kingdom cards from the given [expansions].
  Future<List<DominionCard>> forExpansions(Set<Expansion> expansions) async {
    final all = await loadAll();
    return all
        .where((c) =>
            expansions.contains(c.expansion) &&
            c.isKingdomCard &&
            !c.isDisabled)
        .toList();
  }

  /// Returns cards grouped by expansion.
  Future<Map<Expansion, List<DominionCard>>> groupedByExpansion() async {
    final all = await loadAll();
    final map = <Expansion, List<DominionCard>>{};
    for (final card in all) {
      if (card.isDisabled) continue;
      map.putIfAbsent(card.expansion, () => []).add(card);
    }
    // Sort each group by cost then name for stable display ordering.
    for (final list in map.values) {
      list.sort((a, b) {
        final c = a.cost.compareTo(b.cost);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    }
    return map;
  }

  /// Returns the set of expansions that have at least one card in the data.
  Future<Set<Expansion>> availableExpansions() async {
    final all = await loadAll();
    return all.map((c) => c.expansion).toSet();
  }

  /// Invalidates the cache (useful in tests or after hot-reload).
  void invalidate() => _cache = null;
}
