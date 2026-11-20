import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/table_checklist.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/services/history_service.dart';

Map<String, String> deckChoices(Iterable<String> ids) => {
      for (final entry in ids.toList().asMap().entries)
        'black_market:${entry.key + 1}': entry.value,
    };
List<String> deckIds(SetupResult board) => [
      for (final entry in board.setupChoices.entries)
        if (entry.key.startsWith('black_market:')) entry.value,
    ];

void main() {
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((raw) => KingdomCard.fromJson(raw as Map<String, dynamic>))
          .toList();
  final byId = {for (final card in catalogue) card.id: card};
  final main = [
    'black_market',
    'cellar',
    'chapel',
    'moat',
    'merchant',
    'vassal',
    'harbinger',
    'poacher',
    'workshop',
    'militia'
  ].map((id) => byId[id]!).toList();
  SetupResult board(
          {List<KingdomCard>? kingdom,
          List<KingdomCard> landscapes = const []}) =>
      SetupResult(
          kingdomCards: kingdom ?? main,
          landscapeCards: landscapes,
          archetypes: [],
          setupNotes: [],
          playerCount: 2,
          generatedAt: DateTime(2026));
  const config = ConfigState(
      ownedExpansions: {Expansion.baseSecondEdition},
      rules: SetupRules(),
      disabledCardIds: {});

  test(
      'automatic deck uses unused permitted piles and survives rerolls/replacement',
      () {
    final pool = catalogue
        .where((card) =>
            (card.expansion == Expansion.baseSecondEdition &&
                !card.firstEditionOnly) ||
            card.id == 'black_market')
        .toList();
    final engine = SetupEngine(random: Random(4));
    final result = engine.generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.promos},
        rules: const SetupRules(),
        excludedCardIds: {'smithy'},
        lockedKingdomCards: main);
    expect(result.kingdomSlotIds, hasLength(10));
    final deck = deckIds(result);
    expect(deck, hasLength(15));
    expect(deck.toSet(), hasLength(15));
    expect(deck, isNot(contains('smithy')));
    expect(deck.any(result.kingdomSlotIds.contains), isFalse);
    final rerolled = engine.generate(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.promos},
        rules: const SetupRules(),
        excludedCardIds: {'smithy'},
        lockedKingdomCards: main,
        previousSetupChoices: result.setupChoices);
    expect(deckIds(rerolled), deck);
    final options = engine.replacementOptions(
        allCards: pool,
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.promos},
        rules: const SetupRules(),
        current: result.copyWith(lockedSlotIds: {}),
        outgoingSlotId: 'cellar',
        incomingSlotId: deck.first);
    final replaced =
        result.copyWith(setupChoices: options[deck.first]!.setupChoices);
    expect(deckIds(replaced), isNot(contains(deck.first)));
    expect(deckIds(replaced), hasLength(15));
  });

  test('deck setup resolves nested piles, landscapes, Boons and global effects',
      () {
    const ids = [
      'young_witch',
      'riverboat',
      'druid',
      'underling',
      'kitsune',
      'familiar',
      'tournament',
      'baker',
      'footpad',
      'rats',
      'encampment',
      'dame_anna',
      'opulent_castle',
      'charlatan',
      'shaman'
    ];
    final choices = {
      ...deckChoices(ids),
      'young_witch': 'chancellor',
      'riverboat': 'ferryman',
      'ferryman': 'village',
      'approaching_army': 'noble_brigand',
      'druid_boon_1': 'the_swamps_gift',
      'druid_boon_2': 'the_fields_gift',
      'druid_boon_3': 'the_flames_gift'
    };
    final result = SetupEngine(random: Random(5)).completeTableSetup(
        board(
            landscapes: [byId['forest_dwellers']!, byId['approaching_army']!]),
        catalogue,
        catalogue: catalogue,
        previous: choices,
        validatePrevious: true);
    expect(result.setupChoices, choices);
    expect(result.kingdomSlotIds, hasLength(10));
    final notes = tableChecklist(result, 2).join(' ');
    for (final text in [
      'Black Market deck (15 cards)',
      'Use all 16 Potions',
      'starts with 1 Coffers',
      'for the whole game',
      'Ferryman: put the Village pile',
      "The Swamp's Gift",
      'one copy each of Bag of Gold'
    ]) {
      expect(notes, contains(text), reason: text);
    }
    expect(notes, contains('Curses are also Treasures producing \$1'));
    expect(notes, contains('must gain a card costing up to \$6'));
    expect(notes, isNot(contains('20 cards in its Supply pile')));
    expect(notes, isNot(contains('shuffle the 10 Knights')));
    expect(notes, isNot(contains('sort the Castle pile')));
    expect(notes, isNot(contains('5 copies of each card')));
    expect(result.landscapeCards.map((card) => card.id),
        unorderedEquals(['forest_dwellers', 'approaching_army']));
    for (final restored in [
      decodeKingdomBackup(encodeKingdomBackup([result]), catalogue).single,
      resolveSharedKingdom(encodeFullSetup(result), catalogue, config),
    ]) {
      expect(restored.setupChoices, choices);
      expect(restored.kingdomSlotIds, hasLength(10));
    }
    final removed = SetupEngine().replacementOptions(
        allCards: catalogue,
        ownedExpansions: Expansion.values.toSet(),
        rules: const SetupRules(),
        current: result,
        outgoingSlotId: 'black_market',
        incomingSlotId: 'festival');
    expect(removed['festival']!.setupChoices, isEmpty);
    expect(removed['festival']!.landscapes, isEmpty);
    expect(removed['festival']!.setupNotes.join(' '),
        isNot(contains('Black Market deck')));
  });

  test('extra Black Market starts a deck outside the main ten piles', () {
    final kingdom = [...main.skip(1), byId['smithy']!];
    final pool = [
      ...kingdom,
      byId['black_market']!,
      ...catalogue.where((card) =>
          card.expansion == Expansion.baseSecondEdition &&
          !card.firstEditionOnly &&
          !kingdom.contains(card))
    ];
    final result = SetupEngine().completeTableSetup(
        board(kingdom: kingdom, landscapes: [byId['way_of_the_mouse']!]), pool,
        catalogue: catalogue, previous: {'way_of_the_mouse': 'black_market'});
    expect(result.kingdomSlotIds, isNot(contains('black_market')));
    expect(result.setupChoices['way_of_the_mouse'], 'black_market');
    expect(deckIds(result), hasLength(15));
  });

  test('real-catalogue decks resolve across seeds and obey eligibility filters',
      () {
    final owned = Expansion.values.toSet();
    for (var seed = 0; seed < 30; seed++) {
      final engine = SetupEngine(random: Random(seed));
      final rules = SetupRules(noPotions: seed.isEven, noCursers: seed.isEven);
      final eligible = engine.eligibleKingdomPool(catalogue, owned, rules,
          excludedCardIds: {'smithy'});
      final result = engine.completeTableSetup(board(), eligible,
          catalogue: catalogue,
          rules: rules,
          landscapePool: catalogue.where((card) => card.isLandscape).toList());
      final deck = deckIds(result);
      expect(deck, hasLength(15), reason: 'seed $seed');
      expect(deck.toSet(), hasLength(15));
      expect(deck.any(result.kingdomSlotIds.contains), isFalse);
      final extras = result.setupChoices.entries
          .where((entry) => !entry.key.startsWith('black_market:'))
          .map((entry) => entry.value);
      expect(deck.any(extras.contains), isFalse);
      expect(deck, isNot(contains('smithy')));
      if (seed.isEven) {
        expect(deck.map((id) => byId[id]!).any((card) => card.potionCost),
            isFalse);
      }
      final restored =
          resolveSharedKingdom(encodeFullSetup(result), catalogue, config);
      expect(restored.setupChoices, result.setupChoices);
    }
  });

  test('small collections reserve dependencies before filling the deck', () {
    final pool = [...main, byId['young_witch']!, byId['chancellor']!];
    final result =
        SetupEngine().completeTableSetup(board(), pool, catalogue: catalogue);
    expect(deckIds(result), ['young_witch']);
    expect(result.setupChoices['young_witch'], 'chancellor');
    expect(result.setupNotes.join(' '), contains('Fewer than 15'));
    final restored =
        resolveSharedKingdom(encodeFullSetup(result), catalogue, config);
    expect(restored.setupChoices, result.setupChoices);
  });

  test('mixed-pile cards obey their own costs and bans', () {
    final engine = SetupEngine();
    const rules = SetupRules(maxCost: 4);
    final eligible = engine.eligibleKingdomPool(
        [...main, byId['castles']!], Expansion.values.toSet(), rules);
    final result = engine.completeTableSetup(board(), eligible,
        catalogue: catalogue, rules: rules, excludedCardIds: {'humble_castle'});
    expect(deckIds(result), ['crumbling_castle']);
    expect(byId[deckIds(result).single]!.cost, lessThanOrEqualTo(4));
  });

  test(
      'imports reject unknown, duplicate, partial, overlapping and orphan decks',
      () {
    final engine = SetupEngine();
    for (final choices in [
      {'black_market:1': 'missing'},
      {'black_market:1': 'smithy', 'black_market:2': 'smithy'},
      {'black_market:2': 'smithy'},
      {'black_market:1': 'cellar'},
      {'black_market:1': 'the_swamps_gift'},
      {'black_market:1': 'dame_anna', 'black_market:2': 'sir_bailey'},
      {
        'black_market:1': 'riverboat',
        'black_market:2': 'encampment',
        'riverboat': 'plunder'
      },
    ]) {
      expect(
          () => engine.completeTableSetup(board(), catalogue,
              catalogue: catalogue, previous: choices, validatePrevious: true),
          throwsFormatException,
          reason: choices.toString());
    }
    expect(
        () => engine.completeTableSetup(
            board(kingdom: [...main.skip(1), byId['smithy']!]), catalogue,
            catalogue: catalogue,
            previous: deckChoices(['festival']),
            validatePrevious: true),
        throwsFormatException);
  });
}
