/// Semantic tags used by the Heuristic Engine to detect strategy archetypes.
/// Tags describe *what a card does*, not what type it is.
enum CardTag {
  // --- Economy / Treasure ---
  plusBuy,
  plusCoin,
  gainTreasure,
  goldGain,
  silverGain,

  // --- Draw / Card Advantage ---
  plusCard,
  drawToX,
  lookAtCards,

  // --- Actions / Chaining ---
  plusAction,
  plusTwoActions,
  villageEffect, // +2 or more actions

  // --- Trashing ---
  trashCards,
  trashForBenefit, // "Trash-to-Victory" combos (Chapel, Forge, etc.)

  // --- Gaining ---
  gainCard,
  gainCheaply,

  // --- Victory Points ---
  gainVictory,
  pointTokens,
  altVictory, // non-Province victory paths

  // --- Attack / Control ---
  attack,
  discard,
  topdeck,
  curse, // hands out curse cards
  junking, // hands out junk (Copper, Estate, etc.)
  spy,

  // --- Defense / Reaction ---
  reaction,
  blockAttack,

  // --- Duration / Long-Term ---
  duration,
  nextTurn,
  extraTurn,

  // --- Misc Engine Parts ---
  sifting, // discard & draw (Cellar-like)
  remodel, // trash-and-gain upgrade
  tutoring, // search deck for specific card
  coffers,
  villagers,
  debt,
  exile,
  tokens,
}

extension CardTagExtension on CardTag {
  String get displayName {
    switch (this) {
      case CardTag.plusBuy:
        return '+Buy';
      case CardTag.plusCoin:
        return '+Coin';
      case CardTag.gainTreasure:
        return 'Gain Treasure';
      case CardTag.goldGain:
        return 'Gain Gold';
      case CardTag.silverGain:
        return 'Gain Silver';
      case CardTag.plusCard:
        return '+Card';
      case CardTag.drawToX:
        return 'Draw to X';
      case CardTag.lookAtCards:
        return 'Look at Cards';
      case CardTag.plusAction:
        return '+Action';
      case CardTag.plusTwoActions:
        return '+2 Actions';
      case CardTag.villageEffect:
        return 'Village (+2 Actions)';
      case CardTag.trashCards:
        return 'Trashing';
      case CardTag.trashForBenefit:
        return 'Trash for Benefit';
      case CardTag.gainCard:
        return 'Gain Card';
      case CardTag.gainCheaply:
        return 'Gain Cheaply';
      case CardTag.gainVictory:
        return 'Gain Victory';
      case CardTag.pointTokens:
        return 'Point Tokens';
      case CardTag.altVictory:
        return 'Alt Victory';
      case CardTag.attack:
        return 'Attack';
      case CardTag.discard:
        return 'Discard Attack';
      case CardTag.topdeck:
        return 'Topdeck';
      case CardTag.curse:
        return 'Curse Giver';
      case CardTag.junking:
        return 'Junking Attack';
      case CardTag.spy:
        return 'Spy';
      case CardTag.reaction:
        return 'Reaction';
      case CardTag.blockAttack:
        return 'Block Attack';
      case CardTag.duration:
        return 'Duration';
      case CardTag.nextTurn:
        return 'Next Turn Effect';
      case CardTag.extraTurn:
        return 'Extra Turn';
      case CardTag.sifting:
        return 'Sifting';
      case CardTag.remodel:
        return 'Remodel/Upgrade';
      case CardTag.tutoring:
        return 'Tutoring';
      case CardTag.coffers:
        return 'Coffers';
      case CardTag.villagers:
        return 'Villagers';
      case CardTag.debt:
        return 'Debt';
      case CardTag.exile:
        return 'Exile';
      case CardTag.tokens:
        return 'Tokens';
    }
  }
}
