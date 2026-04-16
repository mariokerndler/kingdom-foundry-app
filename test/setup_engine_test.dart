import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/controllers/setup_exception.dart';
import 'package:kingdom_foundry/models/card_metadata.dart';
import 'package:kingdom_foundry/models/card_tag.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/cost_curve_rule.dart';
import 'package:kingdom_foundry/models/game_vibe_preset.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';

// ── Test helpers ───────────────────────────────────────────────────────────

/// Creates a minimal kingdom card for testing.
KingdomCard _card({
  required String id,
  String? name,
  List<CardType> types = const [CardType.action],
  List<CardTag> tags = const [],
  int cost = 3,
  Expansion expansion = Expansion.baseSecondEdition,
  bool isDisabled = false,
  bool potionCost = false,
  int? debtCost,
  String? splitPileId,
  List<String> pileCards = const [],
  CardMetadata metadata = const CardMetadata(),
}) =>
    KingdomCard(
      id: id,
      name: name ?? id,
      expansion: expansion,
      types: types,
      tags: tags,
      cost: cost,
      potionCost: potionCost,
      debtCost: debtCost,
      text: '',
      metadata: metadata,
      isDisabled: isDisabled,
      splitPileId: splitPileId,
      pileCards: pileCards,
    );

/// Builds a pool of [n] generic action cards.
List<KingdomCard> _pool(
  int n, {
  Expansion expansion = Expansion.baseSecondEdition,
}) =>
    List.generate(n, (i) => _card(id: 'card_$i', expansion: expansion));

/// Engine with a fixed seed for reproducibility.
SetupEngine _seededEngine([int seed = 42]) => SetupEngine(random: Random(seed));

Map<String, int> _bucketCounts(List<KingdomCard> kingdom) {
  final slots = <String, int>{};
  for (final card in kingdom) {
    final slotId = card.splitPileId ?? card.id;
    final current = slots[slotId];
    if (current == null || card.cost < current) {
      slots[slotId] = card.cost;
    }
  }

  final counts = {'<=2': 0, '3': 0, '4': 0, '5': 0, '6+': 0};
  for (final cost in slots.values) {
    if (cost <= 2) {
      counts['<=2'] = counts['<=2']! + 1;
    } else if (cost == 3) {
      counts['3'] = counts['3']! + 1;
    } else if (cost == 4) {
      counts['4'] = counts['4']! + 1;
    } else if (cost == 5) {
      counts['5'] = counts['5']! + 1;
    } else {
      counts['6+'] = counts['6+']! + 1;
    }
  }
  return counts;
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('SetupEngine — basic generation', () {
    test('produces exactly 10 kingdom cards', () {
      final result = _seededEngine().generate(
        allCards: _pool(25),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      expect(result.kingdomCards, hasLength(10));
    });

    test('result cards are all kingdom cards', () {
      final result = _seededEngine().generate(
        allCards: _pool(20),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      expect(result.kingdomCards.every((c) => c.isKingdomCard), isTrue);
    });

    test('output is sorted by cost ascending', () {
      final cards = [
        _card(id: 'a', cost: 5),
        _card(id: 'b', cost: 2),
        _card(id: 'c', cost: 7),
        _card(id: 'd', cost: 4),
        _card(id: 'e', cost: 3),
        _card(id: 'f', cost: 6),
        _card(id: 'g', cost: 1),
        _card(id: 'h', cost: 4),
        _card(id: 'i', cost: 5),
        _card(id: 'j', cost: 3),
      ];
      final result = _seededEngine().generate(
        allCards: cards,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      final costs = result.kingdomCards.map((c) => c.cost).toList();
      expect(costs, equals([...costs]..sort()));
    });

    test('generatedAt timestamp is recent', () {
      final before = DateTime.now();
      final result = _seededEngine().generate(
        allCards: _pool(15),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      final after = DateTime.now();
      expect(
          result.generatedAt
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(result.generatedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });
  });

  group('SetupEngine — expansion filter', () {
    test('only includes cards from owned expansions', () {
      final base = _pool(15, expansion: Expansion.baseSecondEdition);
      final intrigue = _pool(15, expansion: Expansion.intrigueSecondEdition);

      final result = _seededEngine().generate(
        allCards: [...base, ...intrigue],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      expect(
        result.kingdomCards
            .every((c) => c.expansion == Expansion.baseSecondEdition),
        isTrue,
      );
    });

    test('selects from multiple owned expansions', () {
      final base = _pool(15, expansion: Expansion.baseSecondEdition);
      final intrigue = _pool(15, expansion: Expansion.intrigueSecondEdition);

      final result = _seededEngine(99).generate(
        allCards: [...base, ...intrigue],
        ownedExpansions: {
          Expansion.baseSecondEdition,
          Expansion.intrigueSecondEdition
        },
        rules: const SetupRules(),
      );
      final expansions = result.kingdomCards.map((c) => c.expansion).toSet();
      // Not guaranteed to span both, but pool is mixed so usually true —
      // just assert no card comes from an unowned set.
      expect(
        result.kingdomCards.every((c) =>
            c.expansion == Expansion.baseSecondEdition ||
            c.expansion == Expansion.intrigueSecondEdition),
        isTrue,
      );
      expect(
        expansions.every((e) =>
            e == Expansion.baseSecondEdition ||
            e == Expansion.intrigueSecondEdition),
        isTrue,
      );
    });
  });

  group('SetupEngine — pool size errors', () {
    test('throws poolTooSmall when fewer than 10 cards available', () {
      expect(
        () => _seededEngine().generate(
          allCards: _pool(8),
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(),
        ),
        throwsA(
          isA<SetupException>().having(
              (e) => e.reason, 'reason', SetupFailureReason.poolTooSmall),
        ),
      );
    });

    test('throws poolTooSmall with exactly 9 cards in pool', () {
      expect(
        () => _seededEngine().generate(
          allCards: _pool(9),
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(),
        ),
        throwsA(isA<SetupException>()),
      );
    });

    test('succeeds with exactly 10 cards', () {
      final result = _seededEngine().generate(
        allCards: _pool(10),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      expect(result.kingdomCards, hasLength(10));
    });
  });

  group('SetupEngine — presets and rerolls', () {
    test('engine builder preset prefers stronger engine support cards', () {
      final engineCards = List.generate(
        10,
        (i) => _card(
          id: 'engine_$i',
          tags: const [
            CardTag.plusCard,
            CardTag.villageEffect,
            CardTag.trashCards,
          ],
          metadata: const CardMetadata(
            engineSupport: EngineSupportLevel.high,
            payloadProfile: PayloadProfile.support,
            complexity: CardComplexity.medium,
            setupWeight: SetupWeight.low,
            drawQuality: QualityLevel.high,
          ),
        ),
      );
      final economyCards = List.generate(
        10,
        (i) => _card(
          id: 'economy_$i',
          tags: const [CardTag.plusCoin, CardTag.gainTreasure],
          metadata: const CardMetadata(
            engineSupport: EngineSupportLevel.low,
            payloadProfile: PayloadProfile.economy,
            complexity: CardComplexity.low,
            setupWeight: SetupWeight.low,
          ),
        ),
      );

      final engineResult = _seededEngine(9).generate(
        allCards: [...engineCards, ...economyCards],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
        preset: GameVibePresets.byId('engine_builder'),
      );
      final bigMoneyResult = _seededEngine(9).generate(
        allCards: [...engineCards, ...economyCards],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
        preset: GameVibePresets.byId('big_money_simple'),
      );

      final enginePresetCount = engineResult.kingdomCards
          .where(
              (card) => card.metadata.engineSupport == EngineSupportLevel.high)
          .length;
      final bigMoneyEngineCount = bigMoneyResult.kingdomCards
          .where(
              (card) => card.metadata.engineSupport == EngineSupportLevel.high)
          .length;

      expect(enginePresetCount, greaterThan(bigMoneyEngineCount));
    });

    test('locked kingdom cards are preserved during reroll generation', () {
      final lockedA = _card(id: 'locked_a', cost: 2);
      final lockedB = _card(id: 'locked_b', cost: 5);
      final pool = [
        lockedA,
        lockedB,
        ...List.generate(20, (i) => _card(id: 'pool_$i', cost: 3 + (i % 3))),
      ];

      final result = _seededEngine(5).generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
        lockedKingdomCards: [lockedA, lockedB],
      );

      expect(result.kingdomCards, contains(lockedA));
      expect(result.kingdomCards, contains(lockedB));
      expect(result.lockedSlotIds, containsAll(['locked_a', 'locked_b']));
    });
  });

  group('SetupEngine — exclusion rules', () {
    test('noAttacks removes all attack cards from result', () {
      final pool = [
        ..._pool(14),
        _card(id: 'militia', types: [CardType.action, CardType.attack]),
        _card(id: 'witch', types: [CardType.action, CardType.attack]),
        _card(id: 'bandit', types: [CardType.action, CardType.attack]),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(noAttacks: true),
      );
      expect(result.kingdomCards.every((c) => !c.isAttack), isTrue);
    });

    test('noDuration removes all duration cards from result', () {
      final pool = [
        ..._pool(14),
        _card(id: 'merchant_ship', types: [CardType.action, CardType.duration]),
        _card(id: 'wharf', types: [CardType.action, CardType.duration]),
        _card(id: 'lighthouse', types: [CardType.action, CardType.duration]),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(noDuration: true),
      );
      expect(result.kingdomCards.every((c) => !c.isDuration), isTrue);
    });

    test('noPotions removes potion-cost cards from result', () {
      final pool = [
        ..._pool(13),
        _card(id: 'scrying_pool', potionCost: true),
        _card(id: 'alchemist', potionCost: true),
        _card(id: 'possession', potionCost: true),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(noPotions: true),
      );
      expect(result.kingdomCards.every((c) => !c.potionCost), isTrue);
    });

    test('noDebt removes debt cards from result', () {
      final pool = [
        ..._pool(13),
        _card(id: 'engineer', debtCost: 4),
        _card(id: 'city_quarter', debtCost: 8),
        _card(id: 'overlord', debtCost: 8),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(noDebt: true),
      );
      expect(result.kingdomCards.every((c) => c.debtCost == null), isTrue);
    });

    test('maxCost excludes cards above the cap', () {
      final pool = [
        ..._pool(10).map((c) => _card(id: c.id, cost: 3)),
        _card(id: 'expensive_1', cost: 7),
        _card(id: 'expensive_2', cost: 8),
        _card(id: 'expensive_3', cost: 6),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(maxCost: 5),
      );
      expect(result.kingdomCards.every((c) => c.cost <= 5), isTrue);
    });

    test('isDisabled cards are never selected', () {
      final pool = [
        ..._pool(10),
        _card(id: 'banned_1', isDisabled: true),
        _card(id: 'banned_2', isDisabled: true),
        _card(id: 'banned_3', isDisabled: true),
      ];
      final result = _seededEngine().generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      expect(result.kingdomCards.any((c) => c.isDisabled), isFalse);
    });
  });

  group('SetupEngine — requirement rules', () {
    test('requireVillage guarantees a village card in the result', () {
      final pool = [
        ..._pool(9),
        _card(id: 'village', tags: [CardTag.villageEffect]),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final result = SetupEngine(random: Random(seed)).generate(
          allCards: pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(requireVillage: true),
        );
        expect(
          result.kingdomCards.any((c) => c.hasTag(CardTag.villageEffect)),
          isTrue,
          reason: 'Seed $seed: no village found',
        );
      }
    });

    test('requireTrashing guarantees a trasher in the result', () {
      final pool = [
        ..._pool(9),
        _card(id: 'chapel', tags: [CardTag.trashForBenefit]),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final result = SetupEngine(random: Random(seed)).generate(
          allCards: pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(requireTrashing: true),
        );
        expect(
          result.kingdomCards.any((c) =>
              c.hasTag(CardTag.trashCards) ||
              c.hasTag(CardTag.trashForBenefit)),
          isTrue,
          reason: 'Seed $seed: no trasher found',
        );
      }
    });

    test('requirePlusBuy guarantees a +Buy card in the result', () {
      final pool = [
        ..._pool(9),
        _card(id: 'market', tags: [CardTag.plusBuy]),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final result = SetupEngine(random: Random(seed)).generate(
          allCards: pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(requirePlusBuy: true),
        );
        expect(
          result.kingdomCards.any((c) => c.hasTag(CardTag.plusBuy)),
          isTrue,
          reason: 'Seed $seed: no +Buy card found',
        );
      }
    });

    test('requireVillage throws requirementImpossible when no village in pool',
        () {
      expect(
        () => _seededEngine().generate(
          allCards: _pool(15), // no card has villageEffect tag
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: const SetupRules(requireVillage: true),
        ),
        throwsA(
          isA<SetupException>().having(
            (e) => e.reason,
            'reason',
            SetupFailureReason.requirementImpossible,
          ),
        ),
      );
    });
  });

  group('SetupEngine — no duplicates', () {
    test('result contains no duplicate card ids', () {
      final result = _seededEngine().generate(
        allCards: _pool(30),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      final ids = result.kingdomCards.map((c) => c.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });
  });

  group('SetupEngine — cost curve', () {
    test('disabled cost curve preserves normal generation behavior', () {
      final pool = [
        ...List.generate(12, (i) => _card(id: 'cheap_$i', cost: 2)),
        ...List.generate(12, (i) => _card(id: 'mid_$i', cost: 4)),
        ...List.generate(12, (i) => _card(id: 'high_$i', cost: 6)),
      ];

      final base = SetupEngine(random: Random(17)).generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(),
      );
      final curveDisabled = SetupEngine(random: Random(17)).generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: false,
            cheapCount: 4,
            threeCount: 0,
            fourCount: 3,
            fiveCount: 0,
            sixPlusCount: 3,
          ),
        ),
      );

      expect(
        curveDisabled.kingdomCards.map((c) => c.id).toList(),
        equals(base.kingdomCards.map((c) => c.id).toList()),
      );
    });

    test('enabled cost curve prefers the requested bucket distribution', () {
      final pool = [
        ...List.generate(6, (i) => _card(id: 'cheap_$i', cost: 2)),
        ...List.generate(4, (i) => _card(id: 'three_$i', cost: 3)),
        ...List.generate(4, (i) => _card(id: 'four_$i', cost: 4)),
        ...List.generate(4, (i) => _card(id: 'five_$i', cost: 5)),
        ...List.generate(6, (i) => _card(id: 'six_$i', cost: 6)),
      ];

      final result = SetupEngine(random: Random(9)).generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 2,
            threeCount: 2,
            fourCount: 2,
            fiveCount: 2,
            sixPlusCount: 2,
          ),
        ),
      );

      expect(_bucketCounts(result.kingdomCards), {
        '<=2': 2,
        '3': 2,
        '4': 2,
        '5': 2,
        '6+': 2,
      });
    });

    test('split piles count as one slot for cost curve matching', () {
      final sauna = _card(
        id: 'sauna',
        name: 'Sauna',
        cost: 2,
        splitPileId: 'split_a',
      );
      final avanto = _card(
        id: 'avanto',
        name: 'Avanto',
        cost: 6,
        splitPileId: 'split_a',
      );

      final result = SetupEngine(random: Random(4)).generate(
        allCards: [
          ...List.generate(9, (i) => _card(id: 'five_$i', cost: 5)),
          sauna,
          avanto,
        ],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 1,
            threeCount: 0,
            fourCount: 0,
            fiveCount: 9,
            sixPlusCount: 0,
          ),
        ),
      );

      expect(_bucketCounts(result.kingdomCards), {
        '<=2': 1,
        '3': 0,
        '4': 0,
        '5': 9,
        '6+': 0,
      });
    });

    test('hard rules still win over curve preference', () {
      final result = SetupEngine(random: Random(8)).generate(
        allCards: [
          _card(id: 'village', cost: 4, tags: [CardTag.villageEffect]),
          ...List.generate(12, (i) => _card(id: 'cheap_$i', cost: 2)),
          ...List.generate(12, (i) => _card(id: 'five_$i', cost: 5)),
        ],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          requireVillage: true,
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 5,
            threeCount: 0,
            fourCount: 0,
            fiveCount: 5,
            sixPlusCount: 0,
          ),
        ),
      );

      expect(
        result.kingdomCards.any((c) => c.hasTag(CardTag.villageEffect)),
        isTrue,
      );
    });

    test(
        'impossible curves choose the closest valid kingdom instead of failing',
        () {
      final result = SetupEngine(random: Random(3)).generate(
        allCards: [
          ...List.generate(14, (i) => _card(id: 'four_$i', cost: 4)),
          ...List.generate(14, (i) => _card(id: 'five_$i', cost: 5)),
        ],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 10,
            threeCount: 0,
            fourCount: 0,
            fiveCount: 0,
            sixPlusCount: 0,
          ),
        ),
      );

      expect(result.kingdomCards, hasLength(10));
      expect(
        result.setupNotes.any((note) => note.contains('Cost curve target')),
        isTrue,
      );
    });

    test('enabled cost curve emits target vs actual setup note', () {
      final result = SetupEngine(random: Random(11)).generate(
        allCards: [
          ...List.generate(4, (i) => _card(id: 'cheap_$i', cost: 2)),
          ...List.generate(4, (i) => _card(id: 'three_$i', cost: 3)),
          ...List.generate(4, (i) => _card(id: 'four_$i', cost: 4)),
          ...List.generate(4, (i) => _card(id: 'five_$i', cost: 5)),
          ...List.generate(4, (i) => _card(id: 'six_$i', cost: 6)),
        ],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 2,
            threeCount: 2,
            fourCount: 2,
            fiveCount: 2,
            sixPlusCount: 2,
          ),
        ),
      );

      final note = result.setupNotes.firstWhere(
        (note) => note.contains('Cost curve target'),
      );
      expect(note, contains('actual'));
      expect(note, contains('matched'));
    });
  });

  group('SetupEngine — Allies', () {
    test('liaison cards force exactly one Ally even when landscapes are off',
        () {
      final ally = _card(
        id: 'market_towns',
        types: [CardType.ally],
        expansion: Expansion.allies,
      );
      final liaison = _card(
        id: 'underling',
        types: [CardType.action, CardType.liaison],
        expansion: Expansion.allies,
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), liaison, ally],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.allies},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(result.landscapeCards.where((c) => c.isAlly), hasLength(1));
      expect(result.setupNotes.any((note) => note.contains('Liaison setup')),
          isTrue);
    });

    test('Allies are not drawn without a Liaison', () {
      final ally = _card(
        id: 'market_towns',
        types: [CardType.ally],
        expansion: Expansion.allies,
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(10), ally],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.allies},
        rules: const SetupRules(includeLandscape: true, landscapeAllies: 1),
      );

      expect(result.landscapeCards.where((c) => c.isAlly), isEmpty);
    });
  });

  group('SetupEngine — Alchemy', () {
    test('clusters Alchemy cards when a mixed kingdom includes one', () {
      final alchemyCards = [
        _card(
          id: 'university',
          expansion: Expansion.alchemy,
          tags: [CardTag.villageEffect],
          potionCost: true,
        ),
        _card(
          id: 'alchemist',
          expansion: Expansion.alchemy,
          potionCost: true,
        ),
        _card(
          id: 'familiar',
          expansion: Expansion.alchemy,
          types: [CardType.action, CardType.attack],
          potionCost: true,
        ),
        _card(
          id: 'golem',
          expansion: Expansion.alchemy,
          potionCost: true,
        ),
      ];

      final result = _seededEngine().generate(
        allCards: [..._pool(9), ...alchemyCards],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.alchemy},
        rules: const SetupRules(requireVillage: true),
      );

      final alchemyCount = result.kingdomCards
          .where((c) => c.expansion == Expansion.alchemy)
          .length;
      expect(alchemyCount, inInclusiveRange(3, 5));
      expect(
        result.setupNotes.any((note) => note.contains('Potion Supply pile')),
        isTrue,
      );
    });
  });

  group('SetupEngine — Plunder', () {
    test('draws Traits as landscape cards and emits setup note', () {
      final trait = _card(
        id: 'rich',
        types: [CardType.trait],
        expansion: Expansion.plunder,
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(10), trait],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.plunder},
        rules: const SetupRules(
          landscapeEvents: 0,
          landscapeProjects: 0,
          landscapeLandmarks: 0,
          landscapeWays: 0,
          landscapeAllies: 0,
          landscapeTraits: 1,
        ),
      );

      expect(result.landscapeCards.where((c) => c.isTrait), hasLength(1));
      expect(
        result.setupNotes.any((note) => note.contains('Trait setup')),
        isTrue,
      );
    });

    test('Loot support cards are not kingdom slots but trigger setup note', () {
      final loot = _card(
        id: 'amphora',
        types: [CardType.treasure, CardType.loot],
        expansion: Expansion.plunder,
        isDisabled: true,
      );
      final gainer = _card(
        id: 'sack_of_loot',
        types: [CardType.treasure],
        expansion: Expansion.plunder,
        pileCards: ['Amphora'],
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), gainer, loot],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.plunder},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(result.kingdomCards.any((c) => c.isLoot), isFalse);
      expect(
        result.setupNotes.any((note) => note.contains('Loot pile present')),
        isTrue,
      );
    });
  });

  group('SetupEngine — Rising Sun', () {
    test('omen cards force exactly one Prophecy even with landscapes off', () {
      final omen = _card(
        id: 'poet',
        name: 'Poet',
        types: [CardType.action, CardType.omen],
        expansion: Expansion.risingSun,
      );
      final prophecy = _card(
        id: 'approaching_army',
        name: 'Approaching Army',
        types: [CardType.prophecy],
        expansion: Expansion.risingSun,
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), omen, prophecy],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.risingSun},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(result.landscapeCards.where((c) => c.isProphecy), hasLength(1));
      expect(
        result.setupNotes.any((note) => note.contains('Prophecy present')),
        isTrue,
      );
      expect(
        result.setupNotes
            .any((note) => note.contains('Approaching Army setup')),
        isTrue,
      );
    });

    test('shadow cards emit setup note', () {
      final shadow = _card(
        id: 'alley',
        name: 'Alley',
        types: [CardType.action, CardType.shadow],
        expansion: Expansion.risingSun,
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), shadow],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.risingSun},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(
        result.setupNotes.any((note) => note.contains('Shadow cards present')),
        isTrue,
      );
    });
  });

  group('SetupEngine — Promos', () {
    test('Black Market emits setup note', () {
      final blackMarket = _card(
        id: 'black_market',
        name: 'Black Market',
        expansion: Expansion.promos,
        tags: [CardTag.plusCoin, CardTag.lookAtCards],
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), blackMarket],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.promos},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(
        result.setupNotes.any((note) => note.contains('Black Market present')),
        isTrue,
      );
    });

    test('Sauna and Avanto share one split pile slot', () {
      final sauna = _card(
        id: 'sauna',
        name: 'Sauna',
        expansion: Expansion.promos,
        cost: 4,
        splitPileId: 'promos_sauna_avanto',
      );
      final avanto = _card(
        id: 'avanto',
        name: 'Avanto',
        expansion: Expansion.promos,
        cost: 5,
        splitPileId: 'promos_sauna_avanto',
      );

      final result = _seededEngine().generate(
        allCards: [..._pool(9), sauna, avanto],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.promos},
        rules: const SetupRules(includeLandscape: false),
      );

      expect(result.kingdomCards.any((c) => c.name == 'Sauna'), isTrue);
      expect(result.kingdomCards.any((c) => c.name == 'Avanto'), isTrue);
      expect(
        result.setupNotes
            .any((note) => note.contains('Split pile: Sauna / Avanto')),
        isTrue,
      );
    });
  });
}
