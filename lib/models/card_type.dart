/// All possible card types in the game.
/// A single card can have multiple types (e.g., Action + Attack).
enum CardType {
  action,
  treasure,
  victory,
  curse,
  attack,
  castle,
  command,
  gathering,
  knight,
  looter,
  reaction,
  duration,
  doom,
  fate,
  heirloom,
  hex,
  night,
  reserve,
  traveller,
  liaison,
  omen,
  boon,
  event,
  landmark,
  project,
  way,
  ally,
  loot,
  prophecy,
  trait,
  reward,
  artifact,
  state,
  spirit,
  zombie,
  shadow,
  augur,
  clash,
  fort,
  odyssey,
  townsfolk,
  wizard,
}

extension CardTypeExtension on CardType {
  String get displayName {
    switch (this) {
      case CardType.action:
        return 'Action';
      case CardType.treasure:
        return 'Treasure';
      case CardType.victory:
        return 'Victory';
      case CardType.curse:
        return 'Curse';
      case CardType.attack:
        return 'Attack';
      case CardType.castle:
        return 'Castle';
      case CardType.command:
        return 'Command';
      case CardType.gathering:
        return 'Gathering';
      case CardType.knight:
        return 'Knight';
      case CardType.looter:
        return 'Looter';
      case CardType.reaction:
        return 'Reaction';
      case CardType.duration:
        return 'Duration';
      case CardType.doom:
        return 'Doom';
      case CardType.fate:
        return 'Fate';
      case CardType.heirloom:
        return 'Heirloom';
      case CardType.hex:
        return 'Hex';
      case CardType.night:
        return 'Night';
      case CardType.reserve:
        return 'Reserve';
      case CardType.traveller:
        return 'Traveller';
      case CardType.liaison:
        return 'Liaison';
      case CardType.omen:
        return 'Omen';
      case CardType.boon:
        return 'Boon';
      case CardType.event:
        return 'Event';
      case CardType.landmark:
        return 'Landmark';
      case CardType.project:
        return 'Project';
      case CardType.way:
        return 'Way';
      case CardType.ally:
        return 'Ally';
      case CardType.loot:
        return 'Loot';
      case CardType.prophecy:
        return 'Prophecy';
      case CardType.trait:
        return 'Trait';
      case CardType.reward:
        return 'Reward';
      case CardType.artifact:
        return 'Artifact';
      case CardType.state:
        return 'State';
      case CardType.spirit:
        return 'Spirit';
      case CardType.zombie:
        return 'Zombie';
      case CardType.shadow:
        return 'Shadow';
      case CardType.augur:
        return 'Augur';
      case CardType.clash:
        return 'Clash';
      case CardType.fort:
        return 'Fort';
      case CardType.odyssey:
        return 'Odyssey';
      case CardType.townsfolk:
        return 'Townsfolk';
      case CardType.wizard:
        return 'Wizard';
    }
  }

  bool get isKingdomCard {
    // Cards whose ONLY type is one of these are not kingdom supply cards.
    // Note: pure "traveller" (upgrade cards like Treasure Hunter) are also
    // excluded — but base travellers like Page have ["action","traveller"] so
    // action.isKingdomCard keeps them in the supply.
    return this != CardType.event &&
        this != CardType.landmark &&
        this != CardType.project &&
        this != CardType.way &&
        this != CardType.ally &&
        this != CardType.loot &&
        this != CardType.prophecy &&
        this != CardType.trait &&
        this != CardType.reward &&
        this != CardType.traveller &&
        this != CardType.boon &&
        this != CardType.hex &&
        this != CardType.heirloom &&
        this != CardType.artifact &&
        this != CardType.state &&
        this != CardType.spirit &&
        this != CardType.zombie;
  }
}
