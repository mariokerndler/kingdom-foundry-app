import 'card_type.dart';
import 'card_tag.dart';
import 'expansion.dart';

/// The core data model for every Dominion card.
///
/// A card may have multiple [types] (e.g., Action + Attack) and carries
/// semantic [tags] used by the Heuristic Engine to detect strategy archetypes.
class DominionCard {
  final String       id;
  final String       name;
  final Expansion    expansion;
  final List<CardType> types;
  final List<CardTag>  tags;
  final int          cost;
  final int?         debtCost;
  final bool         potionCost;
  final String       text;
  bool               isDisabled;

  /// If non-null, this card belongs to a split pile (e.g. Encampment/Plunder).
  /// All cards sharing the same [splitPileId] are always selected together and
  /// count as a single kingdom slot.
  final String? splitPileId;

  /// For Traveller chains (Adventures): ordered list of upgrade card names
  /// starting from the card *above* this one.
  /// E.g., Page carries ['Treasure Hunter', 'Warrior', 'Hero', 'Champion'].
  /// The engine emits a setup note; these cards are not added to the kingdom.
  final List<String> travellerChain;

  DominionCard({
    required this.id,
    required this.name,
    required this.expansion,
    required this.types,
    required this.tags,
    required this.cost,
    this.debtCost,
    this.potionCost = false,
    required this.text,
    this.isDisabled = false,
    this.splitPileId,
    this.travellerChain = const [],
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isKingdomCard => types.any((t) => t.isKingdomCard);
  bool get isAction      => types.contains(CardType.action);
  bool get isTreasure    => types.contains(CardType.treasure);
  bool get isVictory     => types.contains(CardType.victory);
  bool get isAttack      => types.contains(CardType.attack);
  bool get isReaction    => types.contains(CardType.reaction);
  bool get isDuration    => types.contains(CardType.duration);
  bool get isNight       => types.contains(CardType.night);
  bool get isEvent       => types.contains(CardType.event);
  bool get isLandmark    => types.contains(CardType.landmark);
  bool get isProject     => types.contains(CardType.project);
  bool get isWay         => types.contains(CardType.way);
  bool get isAlly        => types.contains(CardType.ally);
  bool get isSplitPile   => splitPileId != null;
  bool get isTraveller   => travellerChain.isNotEmpty;

  bool hasTag(CardTag tag) => tags.contains(tag);

  String get typeString => types.map((t) => t.displayName).join(' – ');

  String get costString {
    if (potionCost && debtCost != null) return '\$$cost' 'P+${debtCost!}D';
    if (potionCost)                     return '\$$cost' 'P';
    if (debtCost != null && cost == 0)  return '${debtCost!}D';   // pure debt
    if (debtCost != null)               return '\$$cost+${debtCost!}D';
    return '\$$cost';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory DominionCard.fromJson(Map<String, dynamic> json) {
    return DominionCard(
      id:        json['id'] as String,
      name:      json['name'] as String,
      expansion: Expansion.values.firstWhere(
        (e) => e.name == json['expansion'],
        orElse: () => Expansion.base,
      ),
      types: (json['types'] as List<dynamic>)
          .map((t) => CardType.values.firstWhere(
                (e) => e.name == t,
                orElse: () => CardType.action,
              ))
          .toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((t) => CardTag.values.firstWhere(
                (e) => e.name == t,
                orElse: () => CardTag.plusAction,
              ))
          .toList(),
      cost:           json['cost'] as int,
      debtCost:       json['debtCost'] as int?,
      potionCost:     json['potionCost'] as bool? ?? false,
      text:           json['text'] as String,
      isDisabled:     json['isDisabled'] as bool? ?? false,
      splitPileId:    json['splitPileId'] as String?,
      travellerChain: (json['travellerChain'] as List<dynamic>?)
              ?.cast<String>() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id':        id,
    'name':      name,
    'expansion': expansion.name,
    'types':     types.map((t) => t.name).toList(),
    'tags':      tags.map((t) => t.name).toList(),
    'cost':      cost,
    if (debtCost != null)       'debtCost':       debtCost,
    'potionCost':                potionCost,
    'text':                      text,
    'isDisabled':                isDisabled,
    if (splitPileId != null)     'splitPileId':    splitPileId,
    if (travellerChain.isNotEmpty) 'travellerChain': travellerChain,
  };

  DominionCard copyWith({bool? isDisabled}) => DominionCard(
    id:             id,
    name:           name,
    expansion:      expansion,
    types:          types,
    tags:           tags,
    cost:           cost,
    debtCost:       debtCost,
    potionCost:     potionCost,
    text:           text,
    isDisabled:     isDisabled ?? this.isDisabled,
    splitPileId:    splitPileId,
    travellerChain: travellerChain,
  );

  @override
  bool operator ==(Object other) => other is DominionCard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DominionCard($name, ${expansion.displayName}, $costString)';
}
