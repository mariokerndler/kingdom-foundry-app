import 'card_type.dart';
import 'card_tag.dart';
import 'card_metadata.dart';
import 'expansion.dart';

enum CardRole {
  kingdom('Kingdom'),
  landscape('Landscape'),
  auxiliary('Auxiliary');

  final String label;
  const CardRole(this.label);

  static CardRole legacy(List<CardType> types, bool disabled) {
    if (disabled || types.contains(CardType.loot)) return auxiliary;
    if (types.any((type) => type.isKingdomCard)) return kingdom;
    return types.any(landscapeTypes.contains) ? landscape : auxiliary;
  }

  static const landscapeTypes = {
    CardType.event,
    CardType.landmark,
    CardType.project,
    CardType.way,
    CardType.ally,
    CardType.prophecy,
    CardType.trait
  };
}

/// Resolve IDs from earlier catalogue releases when reading saved data.
String canonicalCardId(String id) => id == 'harem' ? 'farm' : id;

/// The core data model for every kingdom card.
///
/// A card may have multiple [types] (e.g., Action + Attack) and carries
/// semantic [tags] used by the Heuristic Engine to detect strategy archetypes.
class KingdomCard {
  final String id;
  final String name;
  final List<String> alternateNames;
  final Expansion expansion;
  final bool firstEditionOnly;
  final Expansion? originalExpansion;
  final List<CardType> types;
  final List<CardTag> tags;
  final int cost;
  final int? debtCost;
  final bool potionCost;
  final String text;
  final CardMetadata metadata;
  final CardCapabilities capabilities;
  final CardRole role;

  /// If non-null, this card belongs to a split pile (e.g. Encampment/Plunder).
  /// All cards sharing the same [splitPileId] are always selected together and
  /// count as a single kingdom slot.
  final String? splitPileId;

  /// For Traveller/exchange chains: ordered list of set-aside card names
  /// starting from the card *above* this one.
  /// E.g., Page carries ['Treasure Hunter', 'Warrior', 'Hero', 'Champion'],
  /// while Hermit carries ['Madman'].
  /// The engine emits a setup note; these cards are not added to the kingdom.
  final List<String> travellerChain;

  /// Stable links; names above remain display fallbacks for older snapshots.
  final List<String> travellerChainIds;

  /// Additional cards that belong to this pile but do not count as separate
  /// generator slots, such as the individual Knights under the Knights pile.
  final List<String> pileCards;
  final List<String> pileCardIds;

  KingdomCard({
    required this.id,
    required this.name,
    this.alternateNames = const [],
    required this.expansion,
    this.firstEditionOnly = false,
    this.originalExpansion,
    required this.types,
    required this.tags,
    required this.cost,
    this.debtCost,
    this.potionCost = false,
    required this.text,
    this.metadata = const CardMetadata(),
    CardCapabilities? capabilities,
    CardRole? role,
    bool isDisabled = false,
    this.splitPileId,
    this.travellerChain = const [],
    this.travellerChainIds = const [],
    this.pileCards = const [],
    this.pileCardIds = const [],
  })  : role = role ?? CardRole.legacy(types, isDisabled),
        capabilities = capabilities ?? CardCapabilities.fromTags(tags, types);

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isKingdomCard => role == CardRole.kingdom;
  bool get isLandscape => role == CardRole.landscape;
  bool get isAuxiliary => role == CardRole.auxiliary;
  bool get hasExchangeChain =>
      travellerChainIds.isNotEmpty || travellerChain.isNotEmpty;
  bool get isDisabled => isAuxiliary;
  Expansion get printedExpansion => firstEditionOnly
      ? originalExpansion ??
          switch (expansion) {
            Expansion.baseSecondEdition => Expansion.base,
            Expansion.intrigueSecondEdition => Expansion.intrigue,
            Expansion.seasideSecondEdition => Expansion.seaside,
            Expansion.prosperitySecondEdition => Expansion.prosperity,
            Expansion.hinterlandsSecondEdition => Expansion.hinterlands,
            _ => expansion,
          }
      : expansion;
  String get printedExpansionName => firstEditionOnly
      ? '${printedExpansion.displayName} (1st Ed.)'
      : expansion.displayName;
  String get pileId => splitPileId ?? id;
  bool get isAction => types.contains(CardType.action);
  bool get isTreasure => types.contains(CardType.treasure);
  bool get isVictory => types.contains(CardType.victory);
  bool get isAttack => types.contains(CardType.attack);
  bool get isLooter => types.contains(CardType.looter);
  bool get isReaction => types.contains(CardType.reaction);
  bool get isDuration => types.contains(CardType.duration);
  bool get isNight => types.contains(CardType.night);
  bool get isOmen => types.contains(CardType.omen);
  bool get isEvent => types.contains(CardType.event);
  bool get isLandmark => types.contains(CardType.landmark);
  bool get isProject => types.contains(CardType.project);
  bool get isWay => types.contains(CardType.way);
  bool get isAlly => types.contains(CardType.ally);
  bool get isLoot => types.contains(CardType.loot);
  bool get isProphecy => types.contains(CardType.prophecy);
  bool get isTrait => types.contains(CardType.trait);
  bool get isShadow => types.contains(CardType.shadow);
  bool get isLiaison => types.contains(CardType.liaison);
  bool get isSplitPile => splitPileId != null;
  bool get isTraveller => types.contains(CardType.traveller);
  bool get providesExtraActions => capabilities.extraActions > 0;
  bool get providesDraw => capabilities.draw.addsCards;
  bool get trashesOwnCards => capabilities.trashing != TrashingThroughput.none;
  bool get blocksAttacks =>
      capabilities.defensiveReaction || hasTag(CardTag.blockAttack);

  bool hasTag(CardTag tag) => tags.contains(tag);

  String get typeString => types.map((t) => t.displayName).join(' – ');

  String get costString {
    if (potionCost && debtCost != null) return '\$$cost' 'P+${debtCost!}D';
    if (potionCost) return '\$$cost' 'P';
    if (debtCost != null && cost == 0) return '${debtCost!}D'; // pure debt
    if (debtCost != null) return '\$$cost+${debtCost!}D';
    return '\$$cost';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory KingdomCard.fromJson(Map<String, dynamic> json) {
    final id = canonicalCardId(json['id'] as String);
    T readEnum<T extends Enum>(List<T> values, Object? value, String field) =>
        values.firstWhere((entry) => entry.name == value,
            orElse: () =>
                throw FormatException('$id: unknown $field "$value"'));

    final types = (json['types'] as List)
        .map((value) => readEnum(CardType.values, value, 'card type'))
        .toList();
    final role = json.containsKey('role')
        ? readEnum(CardRole.values, json['role'], 'card role')
        : CardRole.legacy(types, json['isDisabled'] as bool? ?? false);
    final tags = (json['tags'] as List)
        .map((value) => readEnum(CardTag.values, value, 'card tag'))
        .toList();
    final cost = json['cost'] as int;
    final debtCost = json['debtCost'] as int?;
    var capabilities = CardCapabilities.fromTags(tags, types);
    if (json.containsKey('capabilities')) {
      try {
        capabilities = CardCapabilities.fromJson(
            json['capabilities'] as Map<String, dynamic>, capabilities);
      } on FormatException catch (error) {
        throw FormatException('$id: ${error.message}');
      } on TypeError {
        throw FormatException('$id: invalid capability fields');
      }
    }
    if (types.isEmpty || cost < 0 || (debtCost != null && debtCost < 0)) {
      throw FormatException('$id: expected card types and nonnegative costs');
    }
    return KingdomCard(
      id: id,
      name: json['name'] as String,
      alternateNames:
          (json['alternateNames'] as List?)?.cast<String>() ?? const [],
      expansion: readEnum(Expansion.values, json['expansion'], 'expansion'),
      firstEditionOnly: json['firstEditionOnly'] as bool? ?? false,
      originalExpansion: json.containsKey('originalExpansion')
          ? readEnum(
              Expansion.values, json['originalExpansion'], 'original expansion')
          : null,
      types: types,
      tags: tags,
      cost: cost,
      debtCost: debtCost,
      potionCost: json['potionCost'] as bool? ?? false,
      text: json['text'] as String,
      capabilities: capabilities,
      metadata: json['metadata'] is Map<String, dynamic>
          ? CardMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : CardMetadata.derived(
              types: types,
              tags: tags,
              capabilities: capabilities,
              potionCost: json['potionCost'] as bool? ?? false,
              debtCost: json['debtCost'] as int?,
              isLandscape: role == CardRole.landscape,
              isSplitPile: json['splitPileId'] != null,
              hasExtraCards: id == 'black_market' ||
                  ((json['pileCardIds'] as List?)?.isNotEmpty ?? false) ||
                  ((json['pileCards'] as List?)?.isNotEmpty ?? false),
              isTraveller: types.contains(CardType.traveller) ||
                  ((json['travellerChainIds'] as List?)?.isNotEmpty ?? false) ||
                  ((json['travellerChain'] as List<dynamic>?)?.isNotEmpty ??
                      false),
            ),
      role: role,
      splitPileId: json['splitPileId'] as String?,
      travellerChain:
          (json['travellerChain'] as List<dynamic>?)?.cast<String>() ??
              const [],
      travellerChainIds:
          (json['travellerChainIds'] as List?)?.cast<String>() ?? const [],
      pileCards:
          (json['pileCards'] as List<dynamic>?)?.cast<String>() ?? const [],
      pileCardIds: (json['pileCardIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (alternateNames.isNotEmpty) 'alternateNames': alternateNames,
        'expansion': expansion.name,
        if (firstEditionOnly) 'firstEditionOnly': true,
        if (originalExpansion != null)
          'originalExpansion': originalExpansion!.name,
        'types': types.map((t) => t.name).toList(),
        'tags': tags.map((t) => t.name).toList(),
        'cost': cost,
        if (debtCost != null) 'debtCost': debtCost,
        'potionCost': potionCost,
        'text': text,
        'metadata': metadata.toJson(),
        'capabilities': capabilities.toJson(),
        'role': role.name,
        if (splitPileId != null) 'splitPileId': splitPileId,
        if (travellerChain.isNotEmpty) 'travellerChain': travellerChain,
        if (travellerChainIds.isNotEmpty)
          'travellerChainIds': travellerChainIds,
        if (pileCards.isNotEmpty) 'pileCards': pileCards,
        if (pileCardIds.isNotEmpty) 'pileCardIds': pileCardIds,
      };

  KingdomCard copyWith({bool? isDisabled, CardMetadata? metadata}) =>
      KingdomCard(
        id: id,
        name: name,
        alternateNames: alternateNames,
        expansion: expansion,
        firstEditionOnly: firstEditionOnly,
        originalExpansion: originalExpansion,
        types: types,
        tags: tags,
        cost: cost,
        debtCost: debtCost,
        potionCost: potionCost,
        text: text,
        metadata: metadata ?? this.metadata,
        capabilities: capabilities,
        role: isDisabled == null ? role : CardRole.legacy(types, isDisabled),
        splitPileId: splitPileId,
        travellerChain: travellerChain,
        travellerChainIds: travellerChainIds,
        pileCards: pileCards,
        pileCardIds: pileCardIds,
      );

  @override
  bool operator ==(Object other) => other is KingdomCard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'KingdomCard($name, ${expansion.displayName}, $costString)';
}
