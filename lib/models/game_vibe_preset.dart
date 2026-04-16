import 'card_metadata.dart';
import 'setup_rules.dart';

class GameVibePreset {
  final String id;
  final String name;
  final String description;
  final String rationale;
  final SetupRules defaultRules;
  final double engineWeight;
  final double economyWeight;
  final double interactionWeight;
  final double simplicityWeight;
  final double setupWeightPreference;
  final double weirdnessWeight;

  const GameVibePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.rationale,
    this.defaultRules = const SetupRules(),
    this.engineWeight = 0,
    this.economyWeight = 0,
    this.interactionWeight = 0,
    this.simplicityWeight = 0,
    this.setupWeightPreference = 0,
    this.weirdnessWeight = 0,
  });

  double scoreCard(CardMetadata metadata) {
    double score = 0;
    score += switch (metadata.engineSupport) {
          EngineSupportLevel.low => 0,
          EngineSupportLevel.medium => 0.7,
          EngineSupportLevel.high => 1.2,
        } *
        engineWeight;
    score += switch (metadata.payloadProfile) {
          PayloadProfile.support => 0.2,
          PayloadProfile.economy => 1.0,
          PayloadProfile.spike => 0.8,
        } *
        economyWeight;
    score += switch (metadata.interactionProfile) {
          InteractionProfile.passive => 0.1,
          InteractionProfile.interactive => 0.8,
          InteractionProfile.attackHeavy => 1.3,
        } *
        interactionWeight;
    score += switch (metadata.complexity) {
          CardComplexity.low => 1.2,
          CardComplexity.medium => 0.7,
          CardComplexity.high => 0.1,
        } *
        simplicityWeight;
    score += switch (metadata.setupWeight) {
          SetupWeight.low => 1.1,
          SetupWeight.medium => 0.6,
          SetupWeight.high => 0.1,
        } *
        setupWeightPreference;
    score += switch (metadata.altVpPressure) {
          AltVpPressure.none => 0.1,
          AltVpPressure.light => 0.3,
          AltVpPressure.medium => 0.8,
          AltVpPressure.heavy => 1.2,
        } *
        weirdnessWeight;
    score += switch (metadata.rerollAffinity) {
          RerollAffinity.sticky => 0.4,
          RerollAffinity.flexible => 0.6,
          RerollAffinity.swingy => 1.0,
        } *
        weirdnessWeight;
    return score;
  }
}

class GameVibePresets {
  static const noneId = 'none';

  static const all = <GameVibePreset>[
    GameVibePreset(
      id: noneId,
      name: 'No Preset',
      description: 'Use only your explicit rules without extra bias.',
      rationale:
          'No vibe preset selected; the generator only honored manual rules.',
    ),
    GameVibePreset(
      id: 'engine_builder',
      name: 'Engine Builder',
      description: 'Prioritize draw, villages, and clean engine support.',
      rationale:
          'This preset favors cards that chain actions, draw deeply, and reward trashing.',
      defaultRules: SetupRules(
          requireVillage: true, requireDraw: true, requireTrashing: true),
      engineWeight: 1.4,
      economyWeight: 0.4,
      simplicityWeight: 0.2,
    ),
    GameVibePreset(
      id: 'big_money_simple',
      name: 'Big Money / Simple',
      description:
          'Lean toward cleaner boards with straightforward payload and lower complexity.',
      rationale:
          'This preset prefers simple economy, lower setup overhead, and fewer fiddly effects.',
      defaultRules: SetupRules(maxAttacks: 1),
      economyWeight: 1.3,
      simplicityWeight: 1.2,
      setupWeightPreference: 1.0,
    ),
    GameVibePreset(
      id: 'interactive_fair',
      name: 'Interactive but Fair',
      description:
          'Encourage player interaction without going full attack-chaos.',
      rationale:
          'This preset biases toward interactive cards while avoiding the harshest attack-heavy boards.',
      defaultRules: SetupRules(requireReactionIfAttacks: true, maxAttacks: 2),
      interactionWeight: 1.0,
      simplicityWeight: 0.4,
    ),
    GameVibePreset(
      id: 'attack_chaos',
      name: 'Attack-heavy Chaos',
      description: 'Embrace disruption, tempo swings, and sharp interaction.',
      rationale:
          'This preset chases higher interaction and swingier cards, including attack pressure.',
      interactionWeight: 1.5,
      weirdnessWeight: 0.8,
      economyWeight: 0.2,
    ),
    GameVibePreset(
      id: 'low_setup_overhead',
      name: 'Low Setup Overhead',
      description: 'Reduce side piles, complicated effects, and setup burden.',
      rationale:
          'This preset prioritizes low-complexity cards and lower setup overhead.',
      defaultRules: SetupRules(noTravellers: true),
      simplicityWeight: 1.0,
      setupWeightPreference: 1.4,
    ),
    GameVibePreset(
      id: 'beginner_friendly',
      name: 'Beginner Friendly',
      description: 'Keep the board readable and welcoming for newer players.',
      rationale:
          'This preset prefers simple, readable cards with softer interaction and lower cognitive load.',
      defaultRules: SetupRules(noCursers: true, maxAttacks: 1),
      simplicityWeight: 1.4,
      setupWeightPreference: 1.0,
      interactionWeight: 0.2,
    ),
    GameVibePreset(
      id: 'weird_showcase',
      name: 'Weird / Showcase',
      description:
          'Push toward unusual boards, alt-VP tension, and swingier setups.',
      rationale:
          'This preset rewards unusual scoring pressure, swingy cards, and memorable setups.',
      weirdnessWeight: 1.5,
      interactionWeight: 0.7,
    ),
  ];

  static GameVibePreset byId(String? id) {
    return all.firstWhere(
      (preset) => preset.id == id,
      orElse: () => all.first,
    );
  }
}
