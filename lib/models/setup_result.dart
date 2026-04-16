import 'card_tag.dart';
import 'kingdom_card.dart';
import 'strategy_archetype.dart';

/// The complete output of a single run of the Setup Engine.
class SetupResult {
  /// The 10 selected Kingdom cards (split-pile pairs count as one slot).
  final List<KingdomCard> kingdomCards;

  /// Landscape cards drawn alongside the kingdom:
  /// Events, Landmarks, Projects, Ways, and Allies.
  /// Empty when no owned expansions contribute landscape cards.
  final List<KingdomCard> landscapeCards;

  /// Strategy archetypes detected by the Heuristic Engine, sorted by strength.
  final List<StrategyArchetype> archetypes;

  /// Special setup reminders (Potion pile, Platinum/Colony, etc.).
  final List<String> setupNotes;

  /// ISO-8601 timestamp of when this result was generated.
  final DateTime generatedAt;

  const SetupResult({
    required this.kingdomCards,
    this.landscapeCards = const [],
    required this.archetypes,
    required this.setupNotes,
    required this.generatedAt,
  });

  // ── Convenience helpers ────────────────────────────────────────────────────

  bool get hasAttacks => kingdomCards.any((c) => c.isAttack);
  bool get hasTrashing => kingdomCards.any((c) => c.hasTag(CardTag.trashCards));
  bool get hasDuration => kingdomCards.any((c) => c.isDuration);
  bool get hasLandscape => landscapeCards.isNotEmpty;

  int get actionCount => kingdomCards.where((c) => c.isAction).length;
  int get treasureCount => kingdomCards.where((c) => c.isTreasure).length;
  int get victoryCount => kingdomCards.where((c) => c.isVictory).length;

  StrategyArchetype? get primaryArchetype =>
      archetypes.isEmpty ? null : archetypes.first;

  /// Stable key used when persisting this result as a saved preset.
  String get storageKey => generatedAt.toIso8601String();

  // ── Serialisation (for history) ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'kingdomCards': kingdomCards.map((c) => c.toJson()).toList(),
        'landscapeCards': landscapeCards.map((c) => c.toJson()).toList(),
        'archetypes': archetypes.map((a) => a.toJson()).toList(),
        'setupNotes': setupNotes,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory SetupResult.fromJson(Map<String, dynamic> json) {
    return SetupResult(
      kingdomCards: (json['kingdomCards'] as List)
          .map((c) => KingdomCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      landscapeCards: (json['landscapeCards'] as List? ?? [])
          .map((c) => KingdomCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      archetypes: (json['archetypes'] as List)
          .map((a) => StrategyArchetype.fromJson(a as Map<String, dynamic>))
          .toList(),
      setupNotes: (json['setupNotes'] as List).cast<String>(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}
