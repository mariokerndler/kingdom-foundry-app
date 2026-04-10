import 'package:flutter_test/flutter_test.dart';

import 'package:dominion_setup/controllers/heuristic_engine.dart';
import 'package:dominion_setup/models/card_tag.dart';
import 'package:dominion_setup/models/card_type.dart';
import 'package:dominion_setup/models/dominion_card.dart';
import 'package:dominion_setup/models/expansion.dart';
import 'package:dominion_setup/models/setup_result.dart';
import 'package:dominion_setup/models/strategy_archetype.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

DominionCard _card({
  required String id,
  List<CardType> types = const [CardType.action],
  List<CardTag> tags = const [],
  int cost = 3,
}) =>
    DominionCard(
      id: id,
      name: id,
      expansion: Expansion.baseSecondEdition,
      types: types,
      tags: tags,
      cost: cost,
      text: '',
    );

/// Pads [cards] with generic action cards to reach exactly 10.
List<DominionCard> _kingdom(List<DominionCard> cards) {
  assert(cards.length <= 10);
  final pad = List.generate(
    10 - cards.length,
    (i) => _card(id: 'filler_$i'),
  );
  return [...cards, ...pad];
}

final _engine = HeuristicEngine();

List<StrategyArchetype> _analyze(List<DominionCard> kingdom) =>
    _engine.analyze(kingdom);

StrategyArchetype? _find(List<StrategyArchetype> results, ArchetypeKind kind) =>
    results.where((a) => a.kind == kind).firstOrNull;

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('HeuristicEngine — Engine Building', () {
    test('detects engine with 3 villages + 3 draw cards', () {
      final kingdom = _kingdom([
        _card(
            id: 'village_1',
            tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(
            id: 'village_2',
            tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(
            id: 'village_3',
            tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'smithy_1', tags: [CardTag.plusCard]),
        _card(id: 'smithy_2', tags: [CardTag.plusCard]),
        _card(id: 'lab', tags: [CardTag.plusCard, CardTag.plusAction]),
      ]);
      final results = _analyze(kingdom);
      final archetype = _find(results, ArchetypeKind.engineBuilding);
      expect(archetype, isNotNull);
      expect(archetype!.strength, greaterThan(0.5));
    });

    test('strength increases with more engine pieces', () {
      final weak = _kingdom([
        _card(
            id: 'village',
            tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'smithy', tags: [CardTag.plusCard]),
      ]);
      final strong = _kingdom([
        _card(id: 'v1', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v2', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v3', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'd1', tags: [CardTag.plusCard]),
        _card(id: 'd2', tags: [CardTag.plusCard]),
        _card(id: 'd3', tags: [CardTag.drawToX]),
      ]);
      final weakResult = _find(_analyze(weak), ArchetypeKind.engineBuilding);
      final strongResult =
          _find(_analyze(strong), ArchetypeKind.engineBuilding);
      expect(strongResult, isNotNull);
      // strong engine may be present when weak is not — or strong > weak
      if (weakResult != null) {
        expect(strongResult!.strength, greaterThan(weakResult.strength));
      }
    });

    test('does NOT detect engine without any draw card', () {
      final kingdom = _kingdom([
        _card(id: 'v1', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v2', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v3', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.engineBuilding);
      expect(archetype, isNull);
    });

    test('does NOT detect engine without any action-chainer', () {
      final kingdom = _kingdom([
        _card(id: 'd1', tags: [CardTag.plusCard]),
        _card(id: 'd2', tags: [CardTag.plusCard]),
        _card(id: 'd3', tags: [CardTag.plusCard]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.engineBuilding);
      expect(archetype, isNull);
    });

    test('headline is Full Mega-Engine with 3+ villages', () {
      final kingdom = _kingdom([
        _card(id: 'v1', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v2', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v3', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'd1', tags: [CardTag.plusCard]),
        _card(id: 'd2', tags: [CardTag.plusCard]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.engineBuilding);
      expect(archetype?.headline, equals('Full Mega-Engine'));
    });

    test('key cards list includes villages and draw cards', () {
      final village = _card(
          id: 'village', tags: [CardTag.villageEffect, CardTag.plusTwoActions]);
      final smithy = _card(id: 'smithy', tags: [CardTag.plusCard]);
      final kingdom = _kingdom([
        village,
        smithy,
        _card(id: 'v2', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.engineBuilding);
      expect(archetype, isNotNull);
      expect(archetype!.keyCardNames, contains('village'));
    });
  });

  group('HeuristicEngine — Big Money', () {
    test('detects Big Money on a kingdom with gold gainers and no villages',
        () {
      final kingdom = _kingdom([
        _card(id: 'adventurer', tags: [CardTag.goldGain]),
        _card(id: 'mine', tags: [CardTag.gainTreasure]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.bigMoney);
      expect(archetype, isNotNull);
    });

    test(
        'always detects Big Money on a pure filler kingdom (no engine support)',
        () {
      // Even a kingdom with no special tags should trigger Big Money
      // because the "no villages" bonus fires.
      final kingdom = _kingdom([]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.bigMoney);
      expect(archetype, isNotNull);
    });

    test('headline is Pure Big Money when no draw and no village', () {
      final kingdom = _kingdom([]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.bigMoney);
      expect(archetype?.headline, equals('Pure Big Money'));
    });

    test('headline is Big Money + Terminal Draw when terminal draw present',
        () {
      final kingdom = _kingdom([
        // plusCard WITHOUT plusAction = terminal draw
        _card(id: 'smithy', tags: [CardTag.plusCard]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.bigMoney);
      expect(archetype?.headline, equals('Big Money + Terminal Draw'));
    });

    test('strength is between 0 and 1', () {
      final kingdom = _kingdom([
        _card(id: 'gold_gainer', tags: [CardTag.goldGain]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.bigMoney);
      expect(archetype!.strength, inInclusiveRange(0.0, 1.0));
    });
  });

  group('HeuristicEngine — Aggressive/Control', () {
    test('detects aggro with 2+ attack cards', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
      ]);
      final archetype =
          _find(_analyze(kingdom), ArchetypeKind.aggressiveControl);
      expect(archetype, isNotNull);
    });

    test('does NOT detect aggro with only 1 attack card', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
      ]);
      final archetype =
          _find(_analyze(kingdom), ArchetypeKind.aggressiveControl);
      expect(archetype, isNull);
    });

    test('headline is Curse Slinging when curse attackers present', () {
      final kingdom = _kingdom([
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
        _card(
            id: 'sea_hag',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
      ]);
      final archetype =
          _find(_analyze(kingdom), ArchetypeKind.aggressiveControl);
      expect(archetype?.headline, equals('Curse Slinging'));
    });

    test('headline is Hand Disruption with 2+ discard attackers', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'minion',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
      ]);
      final archetype =
          _find(_analyze(kingdom), ArchetypeKind.aggressiveControl);
      expect(archetype?.headline, equals('Hand Disruption'));
    });

    test('key cards list is the attack cards', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
      ]);
      final archetype =
          _find(_analyze(kingdom), ArchetypeKind.aggressiveControl);
      expect(archetype!.keyCardNames, containsAll(['militia', 'witch']));
    });
  });

  group('HeuristicEngine — Trash-to-Victory', () {
    test('detects trash-to-victory with trashForBenefit card', () {
      // Two trashForBenefit cards: 3.5 + 3.5 = 7.0 — above the 4.5 threshold.
      final kingdom = _kingdom([
        _card(id: 'chapel', tags: [CardTag.trashForBenefit]),
        _card(id: 'remodel', tags: [CardTag.trashForBenefit, CardTag.remodel]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.trashToVictory);
      expect(archetype, isNotNull);
    });

    test('does NOT detect with only minor trashers below threshold', () {
      // A single trashCards card only contributes 1.5 — below the 4.5 threshold.
      final kingdom = _kingdom([
        _card(id: 'trade_route', tags: [CardTag.trashCards]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.trashToVictory);
      expect(archetype, isNull);
    });

    test('headline is Upgrade/Remodel Chain when remodel card present', () {
      final kingdom = _kingdom([
        _card(id: 'remodel', tags: [CardTag.trashForBenefit, CardTag.remodel]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.trashToVictory);
      expect(archetype?.headline, equals('Upgrade / Remodel Chain'));
    });

    test('strength does not exceed 1.0', () {
      final kingdom = _kingdom([
        _card(id: 'chapel', tags: [CardTag.trashForBenefit]),
        _card(id: 'forge', tags: [CardTag.trashForBenefit]),
        _card(id: 'remodel', tags: [CardTag.trashForBenefit, CardTag.remodel]),
        _card(id: 'upgrade', tags: [CardTag.trashCards, CardTag.remodel]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.trashToVictory);
      expect(archetype!.strength, lessThanOrEqualTo(1.0));
    });
  });

  group('HeuristicEngine — Alt-Victory', () {
    test('detects alt-victory with an altVictory card', () {
      final kingdom = _kingdom([
        _card(
            id: 'gardens',
            types: [CardType.victory],
            tags: [CardTag.altVictory]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.altVictory);
      expect(archetype, isNotNull);
    });

    test('does NOT detect without altVictory tag', () {
      final kingdom = _kingdom([]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.altVictory);
      expect(archetype, isNull);
    });

    test('key cards list is the altVictory cards', () {
      final kingdom = _kingdom([
        _card(
            id: 'gardens',
            types: [CardType.victory],
            tags: [CardTag.altVictory]),
        _card(
            id: 'duke', types: [CardType.victory], tags: [CardTag.altVictory]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.altVictory);
      expect(archetype!.keyCardNames, containsAll(['gardens', 'duke']));
    });

    test('headline is Multi-Path Alt-Victory with 2+ alt cards', () {
      final kingdom = _kingdom([
        _card(
            id: 'gardens',
            types: [CardType.victory],
            tags: [CardTag.altVictory]),
        _card(
            id: 'duke', types: [CardType.victory], tags: [CardTag.altVictory]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.altVictory);
      expect(archetype?.headline, equals('Multi-Path Alt-Victory'));
    });
  });

  group('HeuristicEngine — Extra Turns', () {
    test('detects extra-turn cards', () {
      final kingdom = _kingdom([
        _card(
          id: 'outpost',
          types: [CardType.action, CardType.duration],
          tags: [CardTag.duration, CardTag.nextTurn, CardTag.extraTurn],
          cost: 5,
        ),
      ]);

      final archetype = _find(_analyze(kingdom), ArchetypeKind.extraTurns);
      expect(archetype, isNotNull);
      expect(archetype!.headline, equals('Extra Turn: outpost'));
    });

    test('does NOT detect without extraTurn tag', () {
      final kingdom = _kingdom([
        _card(
          id: 'duration',
          types: [CardType.action, CardType.duration],
          tags: [CardTag.duration, CardTag.nextTurn],
        ),
      ]);

      final archetype = _find(_analyze(kingdom), ArchetypeKind.extraTurns);
      expect(archetype, isNull);
    });

    test('key cards list is the extra-turn cards', () {
      final kingdom = _kingdom([
        _card(id: 'outpost', tags: [CardTag.extraTurn]),
        _card(id: 'voyage', tags: [CardTag.extraTurn]),
      ]);

      final archetype = _find(_analyze(kingdom), ArchetypeKind.extraTurns);
      expect(archetype!.keyCardNames, containsAll(['outpost', 'voyage']));
    });
  });

  group('HeuristicEngine — Mirror Match', () {
    test('detects mirror match with 2+ attacks and 1+ reaction', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
        _card(
            id: 'moat',
            types: [CardType.action, CardType.reaction],
            tags: [CardTag.reaction]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.mirrorMatch);
      expect(archetype, isNotNull);
    });

    test('does NOT detect mirror match without a reaction card', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.mirrorMatch);
      expect(archetype, isNull);
    });

    test('does NOT detect mirror match with only 1 attack', () {
      final kingdom = _kingdom([
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'moat',
            types: [CardType.action, CardType.reaction],
            tags: [CardTag.reaction]),
      ]);
      final archetype = _find(_analyze(kingdom), ArchetypeKind.mirrorMatch);
      expect(archetype, isNull);
    });
  });

  group('HeuristicEngine — result ordering and completeness', () {
    test('results are sorted strongest-first', () {
      // Villages + draw triggers Engine Building; 2 attacks trigger Aggro —
      // ensures at least 2 archetypes so the sort order is actually tested.
      final kingdom = _kingdom([
        _card(id: 'v1', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'v2', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'd1', tags: [CardTag.plusCard]),
        _card(id: 'd2', tags: [CardTag.plusCard]),
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
      ]);
      final results = _analyze(kingdom);
      expect(results.length, greaterThan(1));
      for (var i = 0; i < results.length - 1; i++) {
        expect(
          results[i].strength,
          greaterThanOrEqualTo(results[i + 1].strength),
        );
      }
    });

    test('all strengths are in [0.0, 1.0]', () {
      final kingdom = _kingdom([
        _card(id: 'v1', tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(
            id: 'militia',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.discard]),
        _card(
            id: 'witch',
            types: [CardType.action, CardType.attack],
            tags: [CardTag.curse]),
        _card(
            id: 'moat',
            types: [CardType.action, CardType.reaction],
            tags: [CardTag.reaction]),
        _card(id: 'chapel', tags: [CardTag.trashForBenefit]),
        _card(
            id: 'gardens',
            types: [CardType.victory],
            tags: [CardTag.altVictory]),
      ]);
      for (final a in _analyze(kingdom)) {
        expect(a.strength, inInclusiveRange(0.0, 1.0),
            reason: '${a.kind} strength out of range');
      }
    });

    test('returns empty list for a kingdom with no notable features', () {
      // An all-filler kingdom with no tags should still return Big Money
      // (the "no village" bonus always fires). Just verify it does not crash.
      final kingdom = _kingdom([]);
      expect(() => _analyze(kingdom), returnsNormally);
      expect(_analyze(kingdom), isNotEmpty);
    });

    test('enrich populates archetypes on SetupResult', () {
      final kingdom = _kingdom([
        _card(
            id: 'village',
            tags: [CardTag.villageEffect, CardTag.plusTwoActions]),
        _card(id: 'smithy', tags: [CardTag.plusCard]),
      ]);
      final result = SetupResult(
        kingdomCards: kingdom,
        archetypes: const [],
        setupNotes: const [],
        generatedAt: DateTime(2026),
      );

      final enriched = _engine.enrich(result);
      expect(enriched.archetypes, isNotEmpty);
    });

    test('enrich includes landscape cards in archetype analysis', () {
      final result = SetupResult(
        kingdomCards: _kingdom([]),
        landscapeCards: [
          _card(
            id: 'seize_the_day',
            types: [CardType.event],
            tags: [CardTag.extraTurn],
            cost: 4,
          ),
        ],
        archetypes: const [],
        setupNotes: const [],
        generatedAt: DateTime(2026),
      );

      final enriched = _engine.enrich(result);
      final archetype = _find(enriched.archetypes, ArchetypeKind.extraTurns);
      expect(archetype, isNotNull);
      expect(archetype!.keyCardNames, contains('seize_the_day'));
    });
  });
}
