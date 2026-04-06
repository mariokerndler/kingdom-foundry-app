/// All possible card types in Dominion.
/// A single card can have multiple types (e.g., Action + Attack).
enum CardType {
  action,
  treasure,
  victory,
  curse,
  attack,
  reaction,
  duration,
  night,
  reserve,
  traveller,
  event,
  landmark,
  project,
  way,
  ally,
  artifact,
  state,
}

extension CardTypeExtension on CardType {
  String get displayName {
    switch (this) {
      case CardType.action:     return 'Action';
      case CardType.treasure:   return 'Treasure';
      case CardType.victory:    return 'Victory';
      case CardType.curse:      return 'Curse';
      case CardType.attack:     return 'Attack';
      case CardType.reaction:   return 'Reaction';
      case CardType.duration:   return 'Duration';
      case CardType.night:      return 'Night';
      case CardType.reserve:    return 'Reserve';
      case CardType.traveller:  return 'Traveller';
      case CardType.event:      return 'Event';
      case CardType.landmark:   return 'Landmark';
      case CardType.project:    return 'Project';
      case CardType.way:        return 'Way';
      case CardType.ally:       return 'Ally';
      case CardType.artifact:   return 'Artifact';
      case CardType.state:      return 'State';
    }
  }

  bool get isKingdomCard {
    // Events, Landmarks, Projects, Ways, Allies are non-kingdom supply cards
    return this != CardType.event &&
           this != CardType.landmark &&
           this != CardType.project &&
           this != CardType.way &&
           this != CardType.ally &&
           this != CardType.artifact &&
           this != CardType.state;
  }
}
