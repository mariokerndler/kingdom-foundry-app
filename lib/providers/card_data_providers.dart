import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kingdom_card.dart';
import '../controllers/setup_engine.dart';
import '../controllers/setup_exception.dart';
import '../models/expansion.dart';
import 'config_provider.dart';
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

// ── Per-expansion card-count stats ────────────────────────────────────────
// Map<Expansion, ({int kingdom, int landscape})> — derived from allCards.

typedef ExpansionStats = ({int kingdom, int landscape});

final expansionStatsProvider =
    FutureProvider<Map<Expansion, ExpansionStats>>((ref) async {
  final collection = ref.watch(configProvider).collection;
  final all = await ref.watch(allCardsProvider.future);
  final map = <Expansion, ({int kingdom, int landscape})>{};
  final seenPiles = <(Expansion, String)>{};
  for (final c in all) {
    if (c.isAuxiliary || !(collection?.owns(c) ?? !c.firstEditionOnly)) {
      continue;
    }
    if (c.isKingdomCard && !seenPiles.add((c.expansion, c.pileId))) {
      continue;
    }
    final prev = map[c.expansion] ?? (kingdom: 0, landscape: 0);
    map[c.expansion] = c.isKingdomCard
        ? (kingdom: prev.kingdom + 1, landscape: prev.landscape)
        : (kingdom: prev.kingdom, landscape: prev.landscape + 1);
  }
  return map;
});

final selectedKingdomPoolProvider =
    Provider<AsyncValue<List<KingdomCard>>>((ref) {
  final allAsync = ref.watch(allCardsProvider);
  final config = ref.watch(configProvider);

  return allAsync.whenData(
    (all) => SetupEngine().eligibleKingdomPool(
        all, config.ownedExpansions, config.rules,
        excludedCardIds: config.excludedCardIds(all)),
  );
});

final selectedPoolCountProvider = Provider<AsyncValue<int>>((ref) => ref
    .watch(selectedKingdomPoolProvider)
    .whenData((cards) => cards.map((card) => card.pileId).toSet().length));

final selectedPoolConflictProvider = Provider<SetupException?>((ref) {
  final cards = ref.watch(selectedKingdomPoolProvider).valueOrNull;
  final rules = ref.watch(configProvider).rules;
  return cards == null ? null : SetupEngine().poolConflict(cards, rules);
});
