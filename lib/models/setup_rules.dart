import 'cost_curve_rule.dart';

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

  /// Remove cards with the [curse] tag (those that hand out Curse cards,
  /// e.g. Witch, Mountebank). Lighter than [noAttacks].
  final bool noCursers;

  /// Remove Traveller/exchange-chain cards (Page, Peasant, Hermit, Urchin, Vampire)
  /// from the pool to avoid the extra setup of setting aside chained cards.
  final bool noTravellers;

  /// Require at least one +Buy card in the kingdom.
  final bool requirePlusBuy;

  /// Require at least one Trashing card in the kingdom.
  final bool requireTrashing;

  /// Require at least one Village (+2 Actions) card in the kingdom.
  final bool requireVillage;

  /// Require at least one card-draw card (+Card or draw-to-X).
  final bool requireDraw;

  /// If any Attack card ends up in the kingdom, also guarantee at least
  /// one Reaction card. The engine will swap a non-locked, non-attack card
  /// for a random reaction from the pool.
  final bool requireReactionIfAttacks;

  /// Maximum card cost allowed in the kingdom (null = no limit).
  final int? maxCost;

  /// Maximum number of Attack cards allowed in the kingdom (null = no limit).
  final int? maxAttacks;

  /// Minimum number of distinct expansions the 10 cards must span (1 = any).
  final int minExpansionVariety;

  /// When false, no landscape cards
  /// (Events/Landmarks/Projects/Ways/Allies/Traits)
  /// will be drawn even if the owned expansions contain them.
  final bool includeLandscape;

  /// When false, hide heuristic archetype strategy tips on the results screen.
  final bool showStrategyTips;

  /// How many of each landscape type to draw (0 = none).
  /// Defaults reflect the standard rule suggestions.
  final int landscapeEvents;
  final int landscapeProjects;
  final int landscapeLandmarks;
  final int landscapeWays;
  final int landscapeAllies;
  final int landscapeTraits;
  final CostCurveRule costCurve;

  const SetupRules({
    this.noAttacks = false,
    this.noDuration = false,
    this.noPotions = false,
    this.noDebt = false,
    this.noCursers = false,
    this.noTravellers = false,
    this.requirePlusBuy = false,
    this.requireTrashing = false,
    this.requireVillage = false,
    this.requireDraw = false,
    this.requireReactionIfAttacks = false,
    this.maxCost,
    this.maxAttacks,
    this.minExpansionVariety = 1,
    this.includeLandscape = true,
    this.showStrategyTips = true,
    this.landscapeEvents = 2,
    this.landscapeProjects = 2,
    this.landscapeLandmarks = 1,
    this.landscapeWays = 1,
    this.landscapeAllies = 1,
    this.landscapeTraits = 1,
    this.costCurve = const CostCurveRule(),
  });

  factory SetupRules.fromJson(Map<String, dynamic> json) {
    T? read<T>(String key) {
      final value = json[key];
      return value is T ? value : null;
    }

    final rawCurve = read<Map<String, dynamic>>('costCurve');
    return SetupRules(
      noAttacks: read<bool>('noAttacks') ?? false,
      noDuration: read<bool>('noDuration') ?? false,
      noPotions: read<bool>('noPotions') ?? false,
      noDebt: read<bool>('noDebt') ?? false,
      noCursers: read<bool>('noCursers') ?? false,
      noTravellers: read<bool>('noTravellers') ?? false,
      requirePlusBuy: read<bool>('requirePlusBuy') ?? false,
      requireTrashing: read<bool>('requireTrashing') ?? false,
      requireVillage: read<bool>('requireVillage') ?? false,
      requireDraw: read<bool>('requireDraw') ?? false,
      requireReactionIfAttacks: read<bool>('requireReactionIfAttacks') ?? false,
      maxCost: read<int>('maxCost')?.clamp(2, 8),
      maxAttacks: read<int>('maxAttacks')?.clamp(0, 5),
      minExpansionVariety: (read<int>('minExpansionVariety') ?? 1).clamp(1, 10),
      includeLandscape: read<bool>('includeLandscape') ?? true,
      showStrategyTips: read<bool>('showStrategyTips') ?? true,
      landscapeEvents: (read<int>('landscapeEvents') ?? 2).clamp(0, 4),
      landscapeProjects: (read<int>('landscapeProjects') ?? 2).clamp(0, 4),
      landscapeLandmarks: (read<int>('landscapeLandmarks') ?? 1).clamp(0, 3),
      landscapeWays: (read<int>('landscapeWays') ?? 1).clamp(0, 4),
      landscapeAllies: (read<int>('landscapeAllies') ?? 1).clamp(0, 3),
      landscapeTraits: (read<int>('landscapeTraits') ?? 1).clamp(0, 4),
      costCurve: rawCurve == null
          ? const CostCurveRule()
          : CostCurveRule.fromJson(rawCurve),
    );
  }

  SetupRules copyWith({
    bool? noAttacks,
    bool? noDuration,
    bool? noPotions,
    bool? noDebt,
    bool? noCursers,
    bool? noTravellers,
    bool? requirePlusBuy,
    bool? requireTrashing,
    bool? requireVillage,
    bool? requireDraw,
    bool? requireReactionIfAttacks,
    int? maxCost,
    int? maxAttacks,
    int? minExpansionVariety,
    bool? includeLandscape,
    bool? showStrategyTips,
    int? landscapeEvents,
    int? landscapeProjects,
    int? landscapeLandmarks,
    int? landscapeWays,
    int? landscapeAllies,
    int? landscapeTraits,
    CostCurveRule? costCurve,
    bool clearMaxCost = false,
    bool clearMaxAttacks = false,
  }) {
    return SetupRules(
      noAttacks: noAttacks ?? this.noAttacks,
      noDuration: noDuration ?? this.noDuration,
      noPotions: noPotions ?? this.noPotions,
      noDebt: noDebt ?? this.noDebt,
      noCursers: noCursers ?? this.noCursers,
      noTravellers: noTravellers ?? this.noTravellers,
      requirePlusBuy: requirePlusBuy ?? this.requirePlusBuy,
      requireTrashing: requireTrashing ?? this.requireTrashing,
      requireVillage: requireVillage ?? this.requireVillage,
      requireDraw: requireDraw ?? this.requireDraw,
      requireReactionIfAttacks:
          requireReactionIfAttacks ?? this.requireReactionIfAttacks,
      maxCost: clearMaxCost ? null : (maxCost ?? this.maxCost),
      maxAttacks: clearMaxAttacks ? null : (maxAttacks ?? this.maxAttacks),
      minExpansionVariety: minExpansionVariety ?? this.minExpansionVariety,
      includeLandscape: includeLandscape ?? this.includeLandscape,
      showStrategyTips: showStrategyTips ?? this.showStrategyTips,
      landscapeEvents: landscapeEvents ?? this.landscapeEvents,
      landscapeProjects: landscapeProjects ?? this.landscapeProjects,
      landscapeLandmarks: landscapeLandmarks ?? this.landscapeLandmarks,
      landscapeWays: landscapeWays ?? this.landscapeWays,
      landscapeAllies: landscapeAllies ?? this.landscapeAllies,
      landscapeTraits: landscapeTraits ?? this.landscapeTraits,
      costCurve: costCurve ?? this.costCurve,
    );
  }

  /// Human-readable summary of active rules (for display in the UI).
  List<String> get activeRuleDescriptions {
    final rules = <String>[];
    if (noAttacks) rules.add('No Attack cards');
    if (noCursers) rules.add('No Curse-givers');
    if (noDuration) rules.add('No Duration cards');
    if (noPotions) rules.add('No Potion-cost cards');
    if (noDebt) rules.add('No Debt cards');
    if (noTravellers) rules.add('No exchange chains');
    if (requirePlusBuy) rules.add('Must include +Buy');
    if (requireTrashing) rules.add('Must include Trasher');
    if (requireVillage) rules.add('Must include Village');
    if (requireDraw) rules.add('Must include Draw');
    if (requireReactionIfAttacks) rules.add('Auto-Reaction');
    if (maxCost != null) rules.add('Max cost: \$$maxCost');
    if (maxAttacks != null) {
      rules.add('Max $maxAttacks attack${maxAttacks == 1 ? '' : 's'}');
    }
    if (minExpansionVariety > 1) {
      rules.add('At least $minExpansionVariety expansions');
    }
    if (!includeLandscape) rules.add('No landscape cards');
    if (!showStrategyTips) rules.add('Hide strategy tips');
    if (landscapeEvents != 2) rules.add('Events: $landscapeEvents');
    if (landscapeProjects != 2) rules.add('Projects: $landscapeProjects');
    if (landscapeLandmarks != 1) rules.add('Landmarks: $landscapeLandmarks');
    if (landscapeWays != 1) rules.add('Ways: $landscapeWays');
    if (landscapeAllies != 1) rules.add('Allies: $landscapeAllies');
    if (landscapeTraits != 1) rules.add('Traits: $landscapeTraits');
    if (costCurve.enabled) rules.add(costCurve.targetDescription);
    return rules;
  }

  bool get hasActiveRules => activeRuleDescriptions.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'noAttacks': noAttacks,
        'noDuration': noDuration,
        'noPotions': noPotions,
        'noDebt': noDebt,
        'noCursers': noCursers,
        'noTravellers': noTravellers,
        'requirePlusBuy': requirePlusBuy,
        'requireTrashing': requireTrashing,
        'requireVillage': requireVillage,
        'requireDraw': requireDraw,
        'requireReactionIfAttacks': requireReactionIfAttacks,
        'maxCost': maxCost,
        'maxAttacks': maxAttacks,
        'minExpansionVariety': minExpansionVariety,
        'includeLandscape': includeLandscape,
        'showStrategyTips': showStrategyTips,
        'landscapeEvents': landscapeEvents,
        'landscapeProjects': landscapeProjects,
        'landscapeLandmarks': landscapeLandmarks,
        'landscapeWays': landscapeWays,
        'landscapeAllies': landscapeAllies,
        'landscapeTraits': landscapeTraits,
        'costCurve': costCurve.toJson(),
      };
}
