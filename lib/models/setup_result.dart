import 'dart:convert';

import 'kingdom_card.dart';
import 'setup_rules.dart';
import 'strategy_archetype.dart';
import 'table_setup_choice.dart';

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
  final Map<String, String> setupChoices;
  final TableSetupChoice platinumColonyChoice;
  final TableSetupChoice sheltersChoice;

  /// Short rationale strings that explain why this setup matched the preset.
  final List<String> selectionRationale;

  /// The active preset that influenced this board, if any.
  final String? presetId;

  /// Omitted by older history entries and selection-only imports.
  final SetupRules? rulesSnapshot;
  final int? playerCount;
  final String savedName;
  final String savedNotes;

  /// Catalogue used when this board first entered compact storage.
  final String? catalogueRevision;

  /// Stable locked kingdom slot ids for partial rerolls.
  final Set<String> lockedSlotIds;

  /// Stable locked landscape ids for partial rerolls.
  final Set<String> lockedLandscapeIds;

  /// ISO-8601 timestamp of when this result was generated.
  final DateTime generatedAt;

  const SetupResult({
    required this.kingdomCards,
    this.landscapeCards = const [],
    required this.archetypes,
    required this.setupNotes,
    this.setupChoices = const {},
    this.platinumColonyChoice = TableSetupChoice.undecided,
    this.sheltersChoice = TableSetupChoice.undecided,
    this.selectionRationale = const [],
    this.presetId,
    this.rulesSnapshot,
    this.playerCount,
    this.savedName = '',
    this.savedNotes = '',
    this.catalogueRevision,
    this.lockedSlotIds = const {},
    this.lockedLandscapeIds = const {},
    required this.generatedAt,
  });

  // ── Convenience helpers ────────────────────────────────────────────────────

  bool get hasAttacks => kingdomCards.any((c) => c.isAttack);
  bool get hasTrashing => kingdomCards.any((c) => c.trashesOwnCards);
  bool get hasDuration => kingdomCards.any((c) => c.isDuration);
  bool get hasLandscape => landscapeCards.isNotEmpty;
  bool get hasTableSetupChoices =>
      setupChoices.isNotEmpty ||
      platinumColonyChoice != TableSetupChoice.undecided ||
      sheltersChoice != TableSetupChoice.undecided;

  int get actionCount => kingdomCards.where((c) => c.isAction).length;
  int get treasureCount => kingdomCards.where((c) => c.isTreasure).length;
  int get victoryCount => kingdomCards.where((c) => c.isVictory).length;

  StrategyArchetype? get primaryArchetype =>
      archetypes.isEmpty ? null : archetypes.first;

  /// Identity of the generation event in recent history.
  String get storageKey => generatedAt.toIso8601String();

  /// Selection identity independent of generation date and display order.
  String get selectionKey => jsonEncode([
        kingdomSlotIds.toList()..sort(),
        landscapeCards.map((card) => card.id).toSet().toList()..sort(),
      ]);

  Set<String> get kingdomSlotIds =>
      kingdomCards.map((card) => card.pileId).toSet();

  bool isSlotLocked(String slotId) => lockedSlotIds.contains(slotId);
  bool isLandscapeLocked(String cardId) => lockedLandscapeIds.contains(cardId);

  SetupResult copyWith({
    List<KingdomCard>? kingdomCards,
    List<KingdomCard>? landscapeCards,
    List<StrategyArchetype>? archetypes,
    List<String>? setupNotes,
    Map<String, String>? setupChoices,
    TableSetupChoice? platinumColonyChoice,
    TableSetupChoice? sheltersChoice,
    List<String>? selectionRationale,
    String? presetId,
    SetupRules? rulesSnapshot,
    int? playerCount,
    String? savedName,
    String? savedNotes,
    String? catalogueRevision,
    Set<String>? lockedSlotIds,
    Set<String>? lockedLandscapeIds,
    DateTime? generatedAt,
  }) {
    return SetupResult(
      kingdomCards: kingdomCards ?? this.kingdomCards,
      landscapeCards: landscapeCards ?? this.landscapeCards,
      archetypes: archetypes ?? this.archetypes,
      setupNotes: setupNotes ?? this.setupNotes,
      setupChoices: setupChoices ?? this.setupChoices,
      platinumColonyChoice: platinumColonyChoice ?? this.platinumColonyChoice,
      sheltersChoice: sheltersChoice ?? this.sheltersChoice,
      selectionRationale: selectionRationale ?? this.selectionRationale,
      presetId: presetId ?? this.presetId,
      rulesSnapshot: rulesSnapshot ?? this.rulesSnapshot,
      playerCount: playerCount ?? this.playerCount,
      savedName: savedName ?? this.savedName,
      savedNotes: savedNotes ?? this.savedNotes,
      catalogueRevision: catalogueRevision ?? this.catalogueRevision,
      lockedSlotIds: lockedSlotIds ?? this.lockedSlotIds,
      lockedLandscapeIds: lockedLandscapeIds ?? this.lockedLandscapeIds,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  // ── Serialisation (for history) ────────────────────────────────────────────

  Map<String, dynamic> toJson({bool compact = false}) => {
        if (compact) ...{
          'kingdomCardIds': kingdomCards.map((c) => c.id).toList(),
          'landscapeCardIds': landscapeCards.map((c) => c.id).toList(),
        } else ...{
          'kingdomCards': kingdomCards.map((c) => c.toJson()).toList(),
          'landscapeCards': landscapeCards.map((c) => c.toJson()).toList(),
          'archetypes': archetypes.map((a) => a.toJson()).toList(),
        },
        'setupNotes': setupNotes,
        if (setupChoices.isNotEmpty) 'setupChoices': setupChoices,
        if (platinumColonyChoice != TableSetupChoice.undecided)
          'platinumColonyChoice': platinumColonyChoice.name,
        if (sheltersChoice != TableSetupChoice.undecided)
          'sheltersChoice': sheltersChoice.name,
        'selectionRationale': selectionRationale,
        'presetId': presetId,
        if (rulesSnapshot != null) 'rulesSnapshot': rulesSnapshot!.toJson(),
        if (playerCount != null) 'playerCount': playerCount,
        if (savedName.isNotEmpty) 'savedName': savedName,
        if (savedNotes.isNotEmpty) 'savedNotes': savedNotes,
        if (catalogueRevision != null) 'catalogueRevision': catalogueRevision,
        'lockedSlotIds': lockedSlotIds.toList(),
        'lockedLandscapeIds': lockedLandscapeIds.toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory SetupResult.fromJson(Map<String, dynamic> json,
      {Map<String, KingdomCard>? catalogue}) {
    final compact = json.containsKey('kingdomCardIds');
    List<KingdomCard> resolve(String key) => (json[key] as List? ?? const [])
        .cast<String>()
        .map((id) =>
            catalogue?[canonicalCardId(id)] ??
            (throw FormatException('Card unavailable: $id.')))
        .toList();

    return SetupResult(
      kingdomCards: compact
          ? resolve('kingdomCardIds')
          : (json['kingdomCards'] as List)
              .map((c) => KingdomCard.fromJson(c as Map<String, dynamic>))
              .toList(),
      landscapeCards: compact
          ? resolve('landscapeCardIds')
          : (json['landscapeCards'] as List? ?? [])
              .map((c) => KingdomCard.fromJson(c as Map<String, dynamic>))
              .toList(),
      archetypes: (json['archetypes'] as List? ?? const [])
          .map((a) => StrategyArchetype.fromJson(a as Map<String, dynamic>))
          .toList(),
      setupNotes: (json['setupNotes'] as List).cast<String>(),
      setupChoices:
          Map<String, String>.from(json['setupChoices'] as Map? ?? const {})
              .map((key, id) => MapEntry(key, canonicalCardId(id))),
      platinumColonyChoice:
          TableSetupChoice.fromJson(json['platinumColonyChoice']),
      sheltersChoice: TableSetupChoice.fromJson(json['sheltersChoice']),
      selectionRationale:
          (json['selectionRationale'] as List? ?? const []).cast<String>(),
      presetId: json['presetId'] as String?,
      rulesSnapshot: json['rulesSnapshot'] is Map<String, dynamic>
          ? SetupRules.fromJson(json['rulesSnapshot'] as Map<String, dynamic>)
          : null,
      playerCount: (json['playerCount'] as int?)?.clamp(2, 6),
      savedName: (json['savedName'] as String? ?? '').trim(),
      savedNotes: (json['savedNotes'] as String? ?? '').trim(),
      catalogueRevision: json['catalogueRevision'] as String?,
      lockedSlotIds: (json['lockedSlotIds'] as List? ?? const [])
          .cast<String>()
          .map(canonicalCardId)
          .toSet(),
      lockedLandscapeIds:
          ((json['lockedLandscapeIds'] as List? ?? const []).cast<String>())
              .toSet(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}
