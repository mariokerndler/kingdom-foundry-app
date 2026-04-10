import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kingdom_card.dart';
import '../models/expansion.dart';
import '../services/card_data_service.dart';

// ── Singleton service ──────────────────────────────────────────────────────

final cardDataServiceProvider = Provider<CardDataService>(
  (_) => CardDataService(),
);

// ── Raw catalogue (all cards, unfiltered) ─────────────────────────────────

final allCardsProvider = FutureProvider<List<KingdomCard>>((ref) async {
  return ref.read(cardDataServiceProvider).loadAll();
});

// ── Available expansions derived from the data ────────────────────────────

final availableExpansionsProvider = FutureProvider<Set<Expansion>>((ref) async {
  return ref.read(cardDataServiceProvider).availableExpansions();
});

// ── Cards grouped by expansion (for the Configuration list) ──────────────

final cardsByExpansionProvider =
    FutureProvider<Map<Expansion, List<KingdomCard>>>((ref) async {
  return ref.read(cardDataServiceProvider).groupedByExpansion();
});

// ── Per-expansion card-count stats ────────────────────────────────────────
// Map<Expansion, ({int kingdom, int landscape})> — derived from allCards.

typedef ExpansionStats = ({int kingdom, int landscape});

final expansionStatsProvider =
    FutureProvider<Map<Expansion, ExpansionStats>>((ref) async {
  final all = await ref.read(cardDataServiceProvider).loadAll();
  final map = <Expansion, ({int kingdom, int landscape})>{};
  for (final c in all) {
    if (c.isDisabled) continue;
    final prev = map[c.expansion] ?? (kingdom: 0, landscape: 0);
    map[c.expansion] = c.isKingdomCard
        ? (kingdom: prev.kingdom + 1, landscape: prev.landscape)
        : (kingdom: prev.kingdom, landscape: prev.landscape + 1);
  }
  return map;
});
