import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dominion_card.dart';
import '../models/expansion.dart';
import '../services/card_data_service.dart';

// ── Singleton service ──────────────────────────────────────────────────────

final cardDataServiceProvider = Provider<CardDataService>(
  (_) => CardDataService(),
);

// ── Raw catalogue (all cards, unfiltered) ─────────────────────────────────

final allCardsProvider = FutureProvider<List<DominionCard>>((ref) async {
  return ref.read(cardDataServiceProvider).loadAll();
});

// ── Available expansions derived from the data ────────────────────────────

final availableExpansionsProvider = FutureProvider<Set<Expansion>>((ref) async {
  return ref.read(cardDataServiceProvider).availableExpansions();
});

// ── Cards grouped by expansion (for the Configuration list) ──────────────

final cardsByExpansionProvider =
    FutureProvider<Map<Expansion, List<DominionCard>>>((ref) async {
  return ref.read(cardDataServiceProvider).groupedByExpansion();
});
