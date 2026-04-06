import 'card_type.dart';
import 'card_tag.dart';
import 'expansion.dart';

/// The core data model for every Dominion card.
///
/// A card may have multiple [types] (e.g., Action + Attack) and carries
/// semantic [tags] used by the Heuristic Engine to detect strategy archetypes.
class DominionCard {
  final String id;           // Unique slug, e.g. "village", "chapel"
  final String name;
  final Expansion expansion;
  final List<CardType> types;
  final List<CardTag> tags;
  final int cost;            // Coin cost (0-8+)
  final int? debtCost;       // For Empires/debt cards
  final bool potionCost;     // For Alchemy cards
  final String text;         // Card ability text (rules text)
  bool isDisabled;           // User can manually exclude this card

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
  });

  // -------------------------------------------------------------------------
  // Convenience accessors
  // -------------------------------------------------------------------------

  bool get isKingdomCard => types.any((t) => t.isKingdomCard);
  bool get isAction      => types.contains(CardType.action);
  bool get isTreasure    => types.contains(CardType.treasure);
  bool get isVictory     => types.contains(CardType.victory);
  bool get isAttack      => types.contains(CardType.attack);
  bool get isReaction    => types.contains(CardType.reaction);
  bool get isDuration    => types.contains(CardType.duration);
  bool get isNight       => types.contains(CardType.night);

  bool hasTag(CardTag tag) => tags.contains(tag);

  String get typeString => types.map((t) => t.displayName).join(' – ');

  String get costString {
    if (potionCost && debtCost != null) return '\$$cost' 'P+${debtCost!}D';
    if (potionCost)  return '\$$cost' 'P';
    if (debtCost != null) return '\$$cost+${debtCost!}D';
    return '\$$cost';
  }

  // -------------------------------------------------------------------------
  // Serialization
  // -------------------------------------------------------------------------

  factory DominionCard.fromJson(Map<String, dynamic> json) {
    return DominionCard(
      id:          json['id'] as String,
      name:        json['name'] as String,
      expansion:   Expansion.values.firstWhere(
                     (e) => e.name == json['expansion'],
                     orElse: () => Expansion.base,
                   ),
      types:       (json['types'] as List<dynamic>)
                     .map((t) => CardType.values.firstWhere((e) => e.name == t))
                     .toList(),
      tags:        (json['tags'] as List<dynamic>)
                     .map((t) => CardTag.values.firstWhere(
                           (e) => e.name == t,
                           orElse: () => CardTag.plusAction, // fallback
                         ))
                     .toList(),
      cost:        json['cost'] as int,
      debtCost:    json['debtCost'] as int?,
      potionCost:  json['potionCost'] as bool? ?? false,
      text:        json['text'] as String,
      isDisabled:  json['isDisabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':          id,
      'name':        name,
      'expansion':   expansion.name,
      'types':       types.map((t) => t.name).toList(),
      'tags':        tags.map((t) => t.name).toList(),
      'cost':        cost,
      if (debtCost != null) 'debtCost': debtCost,
      'potionCost':  potionCost,
      'text':        text,
      'isDisabled':  isDisabled,
    };
  }

  DominionCard copyWith({bool? isDisabled}) {
    return DominionCard(
      id:          id,
      name:        name,
      expansion:   expansion,
      types:       types,
      tags:        tags,
      cost:        cost,
      debtCost:    debtCost,
      potionCost:  potionCost,
      text:        text,
      isDisabled:  isDisabled ?? this.isDisabled,
    );
  }

  @override
  bool operator ==(Object other) => other is DominionCard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DominionCard($name, ${expansion.displayName}, $costString)';
}
