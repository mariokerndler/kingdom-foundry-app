import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kingdom_card.dart';
import '../models/card_tag.dart';
import '../models/expansion.dart';
import '../models/setup_rules.dart';
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

final selectedPoolCountProvider = Provider<AsyncValue<int>>((ref) {
  final allAsync = ref.watch(allCardsProvider);
  final config = ref.watch(configProvider);

  return allAsync.whenData(
    (all) => all
        .where((card) => _matchesPoolFilters(card, config))
        .length,
  );
});

bool _matchesPoolFilters(KingdomCard card, ConfigState config) {
  final rules = config.rules;

  if (!config.isExpansionOwned(card.expansion) ||
      !card.isKingdomCard ||
      config.isCardDisabled(card.id)) {
    return false;
  }

  return _matchesRuleFilters(card, rules);
}

bool _matchesRuleFilters(KingdomCard card, SetupRules rules) {
  if (rules.noAttacks && card.isAttack) return false;
  if (rules.noDuration && card.isDuration) return false;
  if (rules.noPotions && card.potionCost) return false;
  if (rules.noDebt && card.debtCost != null) return false;
  if (rules.noCursers && card.hasTag(CardTag.curse)) return false;
  if (rules.noTravellers && card.isTraveller) return false;
  if (rules.maxCost != null && card.cost > rules.maxCost!) return false;
  return true;
}
