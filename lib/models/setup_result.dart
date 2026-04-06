import 'card_tag.dart';
import 'dominion_card.dart';
import 'strategy_archetype.dart';

/// The complete output of a single run of the Setup Engine.
class SetupResult {
  /// The 10 selected Kingdom cards.
  final List<DominionCard> kingdomCards;

  /// Strategy archetypes detected by the Heuristic Engine, sorted by strength.
  final List<StrategyArchetype> archetypes;

  /// Any special setup notes (e.g., "Add Platinum & Colony because Prosperity
  /// cards are present", "Use Potion supply pile").
  final List<String> setupNotes;

  /// ISO-8601 timestamp of when this result was generated.
  final DateTime generatedAt;

  const SetupResult({
    required this.kingdomCards,
    required this.archetypes,
    required this.setupNotes,
    required this.generatedAt,
  });

  // -------------------------------------------------------------------------
  // Convenience helpers
  // -------------------------------------------------------------------------

  bool get hasAttacks   => kingdomCards.any((c) => c.isAttack);
  bool get hasTrashing  => kingdomCards.any((c) => c.hasTag(CardTag.trashCards));
  bool get hasDuration  => kingdomCards.any((c) => c.isDuration);

  int get actionCount   => kingdomCards.where((c) => c.isAction).length;
  int get treasureCount => kingdomCards.where((c) => c.isTreasure).length;
  int get victoryCount  => kingdomCards.where((c) => c.isVictory).length;

  StrategyArchetype? get primaryArchetype =>
      archetypes.isEmpty ? null : archetypes.first;
}
