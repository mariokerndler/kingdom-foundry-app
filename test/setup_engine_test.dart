import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dominion_setup/controllers/setup_engine.dart';
import 'package:dominion_setup/controllers/setup_exception.dart';
import 'package:dominion_setup/models/card_tag.dart';
import 'package:dominion_setup/models/card_type.dart';
import 'package:dominion_setup/models/dominion_card.dart';
import 'package:dominion_setup/models/expansion.dart';
import 'package:dominion_setup/models/setup_rules.dart';

// ── Test helpers ───────────────────────────────────────────────────────────

/// Creates a minimal kingdom card for testing.
DominionCard _card({
  required String id,
  List<CardType> types          = const [CardType.action],
  List<CardTag>  tags           = const [],
  int            cost           = 3,
  Expansion      expansion      = Expansion.baseSecondEdition,
  bool           isDisabled     = false,
  bool           potionCost     = false,
  int?           debtCost,
}) =>
    DominionCard(
      id:        id,
      name:      id,
      expansion: expansion,
      types:     types,
      tags:      tags,
      cost:      cost,
      potionCost: potionCost,
      debtCost:  debtCost,
      text:      '',
      isDisabled: isDisabled,
    );

/// Builds a pool of [n] generic action cards.
List<DominionCard> _pool(
  int n, {
  Expansion expansion = Expansion.baseSecondEdition,
}) =>
    List.generate(n, (i) => _card(id: 'card_$i', expansion: expansion));

/// Engine with a fixed seed for reproducibility.
SetupEngine _seededEngine([int seed = 42]) =>
    SetupEngine(random: Random(seed));

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('SetupEngine — basic generation', () {
    test('produces exactly 10 kingdom cards', () {
      final result = _seededEngine().generate(
        allCards:        _pool(25),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      expect(result.kingdomCards, hasLength(10));
    });

    test('result cards are all kingdom cards', () {
      final result = _seededEngine().generate(
        allCards:        _pool(20),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
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
        allCards:        cards,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      final costs = result.kingdomCards.map((c) => c.cost).toList();
      expect(costs, equals([...costs]..sort()));
    });

    test('generatedAt timestamp is recent', () {
      final before = DateTime.now();
      final result = _seededEngine().generate(
        allCards:        _pool(15),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      final after = DateTime.now();
      expect(result.generatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.generatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('SetupEngine — expansion filter', () {
    test('only includes cards from owned expansions', () {
      final base     = _pool(15, expansion: Expansion.baseSecondEdition);
      final intrigue = _pool(15, expansion: Expansion.intrigueSecondEdition);

      final result = _seededEngine().generate(
        allCards:        [...base, ...intrigue],
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      expect(
        result.kingdomCards.every((c) => c.expansion == Expansion.baseSecondEdition),
        isTrue,
      );
    });

    test('selects from multiple owned expansions', () {
      final base     = _pool(15, expansion: Expansion.baseSecondEdition);
      final intrigue = _pool(15, expansion: Expansion.intrigueSecondEdition);

      final result = _seededEngine(99).generate(
        allCards:        [...base, ...intrigue],
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.intrigueSecondEdition},
        rules:           const SetupRules(),
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
      expect(expansions.every((e) =>
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
          allCards:        _pool(8),
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(),
        ),
        throwsA(
          isA<SetupException>()
              .having((e) => e.reason, 'reason', SetupFailureReason.poolTooSmall),
        ),
      );
    });

    test('throws poolTooSmall with exactly 9 cards in pool', () {
      expect(
        () => _seededEngine().generate(
          allCards:        _pool(9),
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(),
        ),
        throwsA(isA<SetupException>()),
      );
    });

    test('succeeds with exactly 10 cards', () {
      final result = _seededEngine().generate(
        allCards:        _pool(10),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      expect(result.kingdomCards, hasLength(10));
    });
  });

  group('SetupEngine — exclusion rules', () {
    test('noAttacks removes all attack cards from result', () {
      final pool = [
        ..._pool(14),
        _card(id: 'militia',  types: [CardType.action, CardType.attack]),
        _card(id: 'witch',    types: [CardType.action, CardType.attack]),
        _card(id: 'bandit',   types: [CardType.action, CardType.attack]),
      ];
      final result = _seededEngine().generate(
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(noAttacks: true),
      );
      expect(result.kingdomCards.every((c) => !c.isAttack), isTrue);
    });

    test('noDuration removes all duration cards from result', () {
      final pool = [
        ..._pool(14),
        _card(id: 'merchant_ship', types: [CardType.action, CardType.duration]),
        _card(id: 'wharf',         types: [CardType.action, CardType.duration]),
        _card(id: 'lighthouse',    types: [CardType.action, CardType.duration]),
      ];
      final result = _seededEngine().generate(
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(noDuration: true),
      );
      expect(result.kingdomCards.every((c) => !c.isDuration), isTrue);
    });

    test('noPotions removes potion-cost cards from result', () {
      final pool = [
        ..._pool(13),
        _card(id: 'scrying_pool', potionCost: true),
        _card(id: 'alchemist',    potionCost: true),
        _card(id: 'possession',   potionCost: true),
      ];
      final result = _seededEngine().generate(
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(noPotions: true),
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
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(noDebt: true),
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
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(maxCost: 5),
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
        allCards:        pool,
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
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
          allCards:        pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(requireVillage: true),
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
          allCards:        pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(requireTrashing: true),
        );
        expect(
          result.kingdomCards.any((c) =>
              c.hasTag(CardTag.trashCards) || c.hasTag(CardTag.trashForBenefit)),
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
          allCards:        pool,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(requirePlusBuy: true),
        );
        expect(
          result.kingdomCards.any((c) => c.hasTag(CardTag.plusBuy)),
          isTrue,
          reason: 'Seed $seed: no +Buy card found',
        );
      }
    });

    test('requireVillage throws requirementImpossible when no village in pool', () {
      expect(
        () => _seededEngine().generate(
          allCards:        _pool(15), // no card has villageEffect tag
          ownedExpansions: {Expansion.baseSecondEdition},
          rules:           const SetupRules(requireVillage: true),
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
        allCards:        _pool(30),
        ownedExpansions: {Expansion.baseSecondEdition},
        rules:           const SetupRules(),
      );
      final ids = result.kingdomCards.map((c) => c.id).toList();
      expect(ids.toSet().length, equals(ids.length));
    });
  });
}
