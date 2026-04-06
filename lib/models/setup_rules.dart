/// Global rule modifiers that act as filter switches in the Setup Engine.
/// The user toggles these on the Configuration screen.
class SetupRules {
  /// Remove all cards with [CardType.attack] from the pool.
  final bool noAttacks;

  /// Remove all cards with [CardType.duration] from the pool.
  final bool noDuration;

  /// Remove all cards requiring a Potion cost (Alchemy dependency).
  final bool noPotions;

  /// Remove all cards that use Debt tokens.
  final bool noDebt;

  /// Require at least one +Buy card in the kingdom.
  final bool requirePlusBuy;

  /// Require at least one Trashing card in the kingdom.
  final bool requireTrashing;

  /// Require at least one Village (+2 Actions) card in the kingdom.
  final bool requireVillage;

  /// Maximum card cost allowed in the kingdom (null = no limit).
  final int? maxCost;

  /// Minimum number of distinct expansions the 10 cards must span (1 = any).
  final int minExpansionVariety;

  const SetupRules({
    this.noAttacks            = false,
    this.noDuration           = false,
    this.noPotions            = false,
    this.noDebt               = false,
    this.requirePlusBuy       = false,
    this.requireTrashing      = false,
    this.requireVillage       = false,
    this.maxCost,
    this.minExpansionVariety  = 1,
  });

  SetupRules copyWith({
    bool? noAttacks,
    bool? noDuration,
    bool? noPotions,
    bool? noDebt,
    bool? requirePlusBuy,
    bool? requireTrashing,
    bool? requireVillage,
    int? maxCost,
    int? minExpansionVariety,
    bool clearMaxCost = false,
  }) {
    return SetupRules(
      noAttacks:           noAttacks           ?? this.noAttacks,
      noDuration:          noDuration          ?? this.noDuration,
      noPotions:           noPotions           ?? this.noPotions,
      noDebt:              noDebt              ?? this.noDebt,
      requirePlusBuy:      requirePlusBuy      ?? this.requirePlusBuy,
      requireTrashing:     requireTrashing     ?? this.requireTrashing,
      requireVillage:      requireVillage      ?? this.requireVillage,
      maxCost:             clearMaxCost ? null : (maxCost ?? this.maxCost),
      minExpansionVariety: minExpansionVariety ?? this.minExpansionVariety,
    );
  }

  /// Human-readable summary of active rules (for display in the UI).
  List<String> get activeRuleDescriptions {
    final rules = <String>[];
    if (noAttacks)          rules.add('No Attack cards');
    if (noDuration)         rules.add('No Duration cards');
    if (noPotions)          rules.add('No Potion-cost cards');
    if (noDebt)             rules.add('No Debt cards');
    if (requirePlusBuy)     rules.add('Must include a +Buy');
    if (requireTrashing)    rules.add('Must include a Trasher');
    if (requireVillage)     rules.add('Must include a Village');
    if (maxCost != null)    rules.add('Max cost: \$$maxCost');
    if (minExpansionVariety > 1) {
      rules.add('At least $minExpansionVariety expansions');
    }
    return rules;
  }

  bool get hasActiveRules => activeRuleDescriptions.isNotEmpty;
}
