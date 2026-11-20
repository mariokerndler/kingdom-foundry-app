import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/table_checklist.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/services/history_service.dart';

KingdomCard card(String id, int cost,
        {List<CardType> types = const [CardType.action],
        int? debt,
        bool potion = false,
        String? split}) =>
    KingdomCard(
      id: id,
      name: id,
      expansion: Expansion.baseSecondEdition,
      types: types,
      tags: [],
      cost: cost,
      text: '',
      debtCost: debt,
      potionCost: potion,
      splitPileId: split,
    );

void main() {
  test(
      'Inherited explains starting-card replacement for its resolved split pile',
      () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .map((raw) => KingdomCard.fromJson(raw as Map<String, dynamic>))
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final main = catalogue
        .where((card) => card.splitPileId == 'allies_townsfolk')
        .toList();
    expect(main, isNotEmpty);
    final result = SetupResult(
        kingdomCards: main,
        landscapeCards: [byId['inherited']!],
        archetypes: [],
        setupNotes: [],
        generatedAt: DateTime(2026));
    final resolved = SetupEngine().completeTableSetup(result, main,
        catalogue: catalogue,
        previous: {'inherited': 'town_crier'},
        validatePrevious: true);
    expect(resolved.setupChoices['inherited'], 'town_crier');
    final notes = tableChecklist(resolved, 6).join(' ');
    expect(notes, contains('Inherited starting decks: in turn order'));
    expect(notes, contains('top card of Town Crier pile'));
    expect(notes, contains('Return replaced Coppers to the Supply'));
    expect(notes, contains('Shelters and Heirlooms back in the box'));
    expect(notes, contains('does not trigger when-gain effects'));
  });

  test(
      'table choices use eligible distinct targets and keep compatible assignments',
      () {
    final kingdom = [
      card('young_witch', 4),
      card('ferryman', 5),
      card('riverboat', 3, types: [CardType.action, CardType.duration]),
      ...List.generate(6, (index) => card('main$index', 4)),
      card('omen', 4, types: [CardType.action, CardType.omen]),
    ];
    final landscapes = [
      card('way_of_the_mouse', 0, types: [CardType.way]),
      card('rich', 0, types: [CardType.trait]),
      card('shy', 0, types: [CardType.trait]),
      card('approaching_army', 0, types: [CardType.prophecy]),
    ];
    final options = [
      card('bane', 2, types: [CardType.treasure], split: 'bane_pile'),
      card('bane_other_member', 4, split: 'bane_pile'),
      card('ferry', 3, types: [CardType.treasure]),
      card('mouse', 3),
      card('boat', 5),
      card('attack', 6, types: [CardType.action, CardType.attack]),
      card('debt', 3, debt: 2),
      card('potion', 2, potion: true),
      card('duration', 5, types: [CardType.action, CardType.duration]),
    ];
    final raw = SetupResult(
        kingdomCards: kingdom,
        landscapeCards: landscapes,
        archetypes: [],
        setupNotes: [],
        generatedAt: DateTime(2026));
    final engine = SetupEngine(random: Random(21));
    const preferred = {
      'young_witch': 'bane',
      'ferryman': 'ferry',
      'riverboat': 'boat',
      'way_of_the_mouse': 'mouse',
      'approaching_army': 'attack',
      'rich': 'main0',
      'shy': 'main1'
    };
    final result = engine.completeTableSetup(raw, [...kingdom, ...options],
        previous: preferred, validatePrevious: true);
    expect(result.setupChoices, preferred);
    expect(result.kingdomSlotIds, hasLength(10));
    expect(result.setupNotes.join(' '), contains('Bane pile'));
    for (var seed = 0; seed < 12; seed++) {
      final resolved = SetupEngine(random: Random(seed))
          .completeTableSetup(raw, [...kingdom, ...options]);
      expect(resolved.setupChoices['riverboat'], 'boat');
      expect(resolved.setupChoices['way_of_the_mouse'], 'mouse');
      expect(resolved.setupChoices['young_witch'], 'bane');
      expect(resolved.setupChoices['ferryman'], 'ferry');
    }

    final replaced = raw.copyWith(kingdomCards: [
      ...kingdom.where((card) => card.id != 'main0'),
      card('replacement', 4),
    ]);
    final updated = engine.completeTableSetup(
        replaced, [...kingdom, ...options],
        previous: preferred);
    expect(updated.setupChoices['rich'], isNot('main0'));
    expect(updated.setupChoices['shy'], 'main1');
    expect(updated.setupChoices['riverboat'], 'boat');
    expect(
        () => engine.completeTableSetup(raw, [...kingdom, ...options],
            previous: {'riverboat': 'duration'}, validatePrevious: true),
        throwsFormatException);
  });

  test('checklist uses player-specific base pile and Prophecy counts', () {
    final result = SetupResult(kingdomCards: [], landscapeCards: [
      card('prophecy', 0, types: [CardType.prophecy])
    ], archetypes: [], setupNotes: [], generatedAt: DateTime(2026));
    final two = tableChecklist(result, 2).join(' ');
    expect(two, contains('8 Provinces and 10 Curses'));
    expect(two, contains('5 Sun tokens'));
    final six = tableChecklist(result, 6).join(' ');
    expect(six, contains('18 Provinces and 50 Curses'));
    expect(six, contains('13 Sun tokens'));
  });

  test('Landmark and Tax setup uses exact starting token quantities', () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final landscapes = [
      for (final id in [
        'arena',
        'basilica',
        'baths',
        'battlefield',
        'colonnade',
        'labyrinth',
        'aqueduct',
        'defiled_shrine',
        'tax',
        'mountain_pass'
      ])
        byId[id]!
    ];
    expect(byId['basilica']!.text, contains('gain a card in your Buy phase'));
    expect(byId['colonnade']!.text,
        contains('gain an Action card in your Buy phase'));
    expect(byId['defiled_shrine']!.text,
        contains('gain a Curse in your Buy phase'));
    final kingdom = catalogue
        .where((card) =>
            card.isKingdomCard && card.expansion == Expansion.baseSecondEdition)
        .take(10)
        .toList();
    final result = SetupResult(
        kingdomCards: kingdom,
        landscapeCards: landscapes,
        archetypes: [],
        playerCount: 5,
        setupNotes: SetupEngine().generateSetupNotes(kingdom, landscapes),
        generatedAt: DateTime(2026));
    final two = tableChecklist(result, 2).join(' ');
    final six = tableChecklist(result, 6).join(' ');
    for (final name in [
      'Arena',
      'Basilica',
      'Baths',
      'Battlefield',
      'Colonnade',
      'Labyrinth'
    ]) {
      expect(two, contains('$name: put 12 VP on this Landmark'));
      expect(six, contains('$name: put 36 VP on this Landmark'));
    }
    expect(two, contains('Aqueduct: put 8 VP on Silver and 8 VP on Gold'));
    expect(
        two,
        contains(
            'Defiled Shrine: put 2 VP on each non-Gathering Action Supply pile'));
    expect(two, contains('Tax: put 1 Debt on every Supply pile'));
    expect(two, isNot(contains('Mountain Pass: put')));
    expect(two, isNot(contains('follow each Landmark')));
    final shared = resolveSharedKingdom(
        encodeFullSetup(result),
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(shared.playerCount, 5);
    expect(tableChecklist(shared, shared.playerCount!).join(' '),
        contains('Arena: put 30 VP on this Landmark'));
  });

  test('special pile quantities include resolved extra piles', () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final raw = SetupResult(kingdomCards: [
      for (final id in [
        'ferryman',
        'castles',
        'herb_gatherer',
        'acolyte',
        'sorceress',
        'sibyl',
        'catapult',
        'rocks',
        'supplies',
        'hermit',
        'urchin',
        'bandit_camp',
        'village',
        'smithy'
      ])
        byId[id]!
    ], archetypes: [], setupNotes: [], generatedAt: DateTime(2026));
    final result = SetupEngine(random: Random(41)).completeTableSetup(
        raw, catalogue,
        previous: {'ferryman': 'rats'}, validatePrevious: true);
    expect(result.kingdomSlotIds, hasLength(10));
    expect(result.setupChoices['ferryman'], 'rats');
    final checklist = tableChecklist(result, 3).join(' ');
    expect(checklist, contains('Rats: use all 20 cards'));
    expect(checklist, contains('4 copies of each card'));
    expect(checklist, contains('5 copies of each card'));
    expect(checklist, contains('12 cards total'));
    expect(checklist, contains('all 30 Horses'));
    expect(checklist, contains('15 Spoils, 10 Madmen, 10 Mercenaries'));
  });

  test('Obelisk can mark the Bane and share a pile with a Trait', () {
    final kingdom = [
      card('young_witch', 4),
      ...List.generate(
          9, (index) => card('treasure$index', 4, types: [CardType.treasure]))
    ];
    final bane = card('bane', 2);
    final outside = card('outside', 5);
    final raw = SetupResult(
        kingdomCards: kingdom,
        landscapeCards: [
          card('obelisk', 0, types: [CardType.landmark]),
          card('rich', 0, types: [CardType.trait])
        ],
        archetypes: [],
        setupNotes: [],
        generatedAt: DateTime(2026));
    const choices = {'young_witch': 'bane', 'obelisk': 'bane', 'rich': 'bane'};
    final engine = SetupEngine(random: Random(42));
    final result = engine.completeTableSetup(raw, [...kingdom, bane, outside],
        previous: choices, validatePrevious: true);
    expect(result.setupChoices, choices);
    expect(result.setupNotes.join(' '),
        contains('Obelisk: mark the bane Supply pile'));
    expect(
        () => engine.completeTableSetup(raw, [...kingdom, bane, outside],
            previous: {...choices, 'obelisk': 'outside'},
            validatePrevious: true),
        throwsFormatException);
    final retained = engine.completeTableSetup(result, [...kingdom, bane],
        previous: result.setupChoices);
    expect(retained.setupChoices['obelisk'], 'bane');
  });

  test('Obelisk Ruins selection survives generation, sharing and backups', () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final treasures = catalogue
        .where((card) =>
            card.isKingdomCard &&
            card.isTreasure &&
            !card.isAction &&
            !card.isSplitPile)
        .take(10)
        .toList();
    final main = [byId['cultist']!, ...treasures.take(9)];
    final engine = SetupEngine(random: Random(43));
    final result = engine.generate(
        allCards: catalogue,
        ownedExpansions: Expansion.values.toSet(),
        rules: const SetupRules(includeLandscape: false),
        lockedKingdomCards: main,
        lockedLandscapeCards: [byId['obelisk']!],
        previousSetupChoices: {'obelisk': 'ruins'});
    expect(result.kingdomSlotIds, hasLength(10));
    expect(result.setupChoices['obelisk'], 'ruins');
    expect(result.setupNotes.join(' '),
        contains('Obelisk: mark the Ruins Supply pile'));
    expect(
        catalogue
            .where((card) => card.types.contains(CardType.ruins))
            .every((card) => card.isAuxiliary),
        isTrue);
    final restored =
        decodeKingdomBackup(encodeKingdomBackup([result]), catalogue).single;
    expect(restored.setupChoices['obelisk'], 'ruins');
    final shared = resolveSharedKingdom(
        encodeFullSetup(result),
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(shared.setupChoices['obelisk'], 'ruins');
    final withoutLooter = result.copyWith(kingdomCards: treasures);
    expect(
        () => engine.completeTableSetup(withoutLooter, catalogue,
            previous: result.setupChoices, validatePrevious: true),
        throwsFormatException);
    final updated = engine.completeTableSetup(withoutLooter, catalogue,
        previous: result.setupChoices);
    expect(updated.setupChoices.containsKey('obelisk'), isFalse);
  });

  test('Druid chooses three distinct Boons and retains them through sharing',
      () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final main = [
      byId['druid']!,
      ...catalogue
          .where((card) =>
              card.isKingdomCard &&
              card.expansion == Expansion.baseSecondEdition)
          .take(9)
    ];
    final engine = SetupEngine(random: Random(44));
    final result = engine.generate(
        allCards: catalogue,
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.nocturne},
        rules: const SetupRules(includeLandscape: false),
        lockedKingdomCards: main);
    expect(result.kingdomSlotIds, hasLength(10));
    expect(result.setupChoices, hasLength(3));
    expect(result.setupChoices.values.toSet(), hasLength(3));
    for (final id in result.setupChoices.values) {
      expect(byId[id]!.types, contains(CardType.boon));
      expect(result.setupNotes.join(' '), contains(byId[id]!.name));
    }
    expect(result.setupNotes.join(' '), contains('remaining 9 Boons'));
    final retained = engine.completeTableSetup(result, catalogue,
        previous: result.setupChoices, validatePrevious: true);
    expect(retained.setupChoices, result.setupChoices);
    final restored =
        decodeKingdomBackup(encodeKingdomBackup([result]), catalogue).single;
    expect(restored.setupChoices, result.setupChoices);
    final shared = resolveSharedKingdom(
        encodeFullSetup(result),
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(shared.setupChoices, result.setupChoices);
    for (final invalid in [
      {'druid_boon_1': result.setupChoices.values.first},
      {...result.setupChoices, 'druid_boon_1': 'village'},
      {
        ...result.setupChoices,
        'druid_boon_2': result.setupChoices['druid_boon_1']!
      }
    ]) {
      expect(
          () => engine.completeTableSetup(result, catalogue,
              previous: invalid, validatePrevious: true),
          throwsFormatException);
    }
    final withoutDruid = result.copyWith(
        kingdomCards: main
            .map((card) => card.id == 'druid' ? byId['witch']! : card)
            .toList());
    expect(
        engine
            .completeTableSetup(withoutDruid, catalogue,
                previous: result.setupChoices)
            .setupChoices,
        isEmpty);
    expect(
        () => engine.completeTableSetup(withoutDruid, catalogue,
            previous: result.setupChoices, validatePrevious: true),
        throwsFormatException);
  });

  test('Druid set aside for the Mouse also resolves its Boons', () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final main = catalogue
        .where((card) =>
            card.isKingdomCard && card.expansion == Expansion.baseSecondEdition)
        .take(10)
        .toList();
    const choices = {
      'way_of_the_mouse': 'druid',
      'druid_boon_1': 'the_swamps_gift',
      'druid_boon_2': 'the_fields_gift',
      'druid_boon_3': 'the_flames_gift'
    };
    final raw = SetupResult(
        kingdomCards: main,
        landscapeCards: [byId['way_of_the_mouse']!],
        archetypes: [],
        setupNotes: [],
        generatedAt: DateTime(2026));
    final engine = SetupEngine(random: Random(45));
    for (var seed = 0; seed < 8; seed++) {
      final result = SetupEngine(random: Random(seed)).completeTableSetup(
          raw, [...main, byId['druid']!],
          catalogue: catalogue, previous: choices, validatePrevious: true);
      expect(result.setupChoices, choices);
      expect(result.setupNotes.join(' '), contains("The Swamp's Gift"));
    }
    final plain = raw.copyWith(landscapeCards: []);
    expect(
        engine
            .completeTableSetup(plain, catalogue, previous: choices)
            .setupChoices,
        isEmpty);
  });

  test('Riverboat through Ferryman and Young Witch survives backup and sharing',
      () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final main = [
      byId['riverboat']!,
      ...catalogue
          .where((card) =>
              card.expansion == Expansion.baseSecondEdition &&
              card.id != 'chapel')
          .take(9),
    ];
    final raw = SetupResult(
        kingdomCards: main,
        landscapeCards: [byId['rich']!],
        archetypes: [],
        setupNotes: [],
        rulesSnapshot: const SetupRules(),
        playerCount: 4,
        generatedAt: DateTime(2026));
    const choices = {
      'riverboat': 'ferryman',
      'ferryman': 'young_witch',
      'young_witch': 'chapel',
      'rich': 'chapel',
    };
    final engine = SetupEngine(random: Random(31));
    final complete = engine.completeTableSetup(raw,
        [...main, byId['ferryman']!, byId['young_witch']!, byId['chapel']!],
        previous: choices);
    expect(complete.setupChoices, choices);
    expect(complete.kingdomSlotIds, hasLength(10));
    final notes = complete.setupNotes.join(' ');
    expect(notes, contains('set aside one copy of Ferryman'));
    expect(notes, contains('the Young Witch pile beside the Supply'));
    expect(notes, contains('the Chapel pile to the Supply as the Bane pile'));

    final backup = encodeKingdomBackup([complete]);
    expect(decodeKingdomBackup(backup, catalogue).single.setupChoices, choices);
    const config = ConfigState(
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: SetupRules(),
        disabledCardIds: {});
    final shared =
        resolveSharedKingdom(encodeFullSetup(complete), catalogue, config);
    expect(shared.setupChoices, choices);
    expect(shared.kingdomSlotIds, complete.kingdomSlotIds);
    expect(
        () => engine.completeTableSetup(raw, catalogue,
            previous: {'young_witch': 'chapel'}, validatePrevious: true),
        throwsFormatException);
  });

  test('extra setup backtracks when a nested effect has no available pile', () {
    final kingdom = [
      card('riverboat', 3, types: [CardType.action, CardType.duration]),
      ...List.generate(9, (index) => card('main$index', 2)),
    ];
    final raw = SetupResult(
        kingdomCards: kingdom,
        archetypes: [],
        setupNotes: [],
        generatedAt: DateTime(2026));
    final ferryman = card('ferryman', 5);
    final plain = card('plain', 5);
    final engine = SetupEngine(random: Random(12));
    final complete = engine.completeTableSetup(
        raw, [...kingdom, ferryman, plain],
        previous: {'riverboat': 'ferryman'});
    expect(complete.setupChoices, {'riverboat': 'plain'});
    final partial = engine.completeTableSetup(raw, [...kingdom, ferryman]);
    expect(partial.setupChoices, {'riverboat': 'ferryman'});
    expect(
        partial.setupNotes.join(' '), contains('Ferryman: choose an unused'));
  });

  test('extra Liaison and Omen bring required landscapes into the board', () {
    final catalogue =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final byId = {for (final card in catalogue) card.id: card};
    final main = [
      byId['young_witch']!,
      byId['riverboat']!,
      ...catalogue
          .where((card) =>
              card.expansion == Expansion.baseSecondEdition &&
              card.id != 'militia')
          .take(8),
    ];
    final eligible = [
      ...main,
      for (final id in [
        'underling',
        'kitsune',
        'militia',
        'approaching_army',
        'forest_dwellers',
      ])
        byId[id]!,
    ];
    final owned = eligible.map((card) => card.expansion).toSet();
    final engine = SetupEngine(random: Random(7));
    const rules = SetupRules(includeLandscape: false);
    final board = engine.generate(
      allCards: eligible,
      ownedExpansions: owned,
      rules: rules,
      lockedKingdomCards: main,
    );
    expect(board.kingdomSlotIds, hasLength(10));
    expect(board.setupChoices, {
      'young_witch': 'underling',
      'riverboat': 'kitsune',
      'approaching_army': 'militia',
    });
    expect(board.landscapeCards.map((card) => card.id),
        unorderedEquals(['forest_dwellers', 'approaching_army']));
    expect(board.setupNotes.join(' '), contains('Favors mat'));

    final rerolled = engine.generate(
      allCards: eligible,
      ownedExpansions: owned,
      rules: rules,
      lockedKingdomCards: main,
      lockedLandscapeCards: board.landscapeCards,
      previousSetupChoices: board.setupChoices,
    );
    expect(rerolled.setupChoices, board.setupChoices);
    expect(
        rerolled.lockedLandscapeIds, {'forest_dwellers', 'approaching_army'});

    final replaceable = rerolled.copyWith(lockedSlotIds: {});
    final options = engine.replacementOptions(
      allCards: eligible,
      ownedExpansions: owned,
      rules: rules,
      current: replaceable,
      outgoingSlotId: 'young_witch',
    );
    expect(options['militia']?.setupChoices, {
      'riverboat': 'kitsune',
      'approaching_army': 'young_witch',
      'young_witch': 'underling',
    });
    expect(
      engine.replacementOptions(
        allCards: eligible,
        ownedExpansions: owned,
        rules: rules,
        current: replaceable,
        outgoingSlotId: 'riverboat',
        incomingSlotId: 'militia',
      ),
      isEmpty,
    );
    expect(options['underling']?.landscapes, rerolled.landscapeCards);
    expect(options['underling']?.setupChoices, {
      'riverboat': 'kitsune',
      'approaching_army': 'militia',
    });
    final rechecked = engine.replacementOptions(
      allCards: eligible,
      ownedExpansions: owned,
      rules: rules,
      current: replaceable,
      outgoingSlotId: 'young_witch',
      incomingSlotId: 'underling',
    );
    expect(rechecked.keys, ['underling']);
    expect(
        rechecked['underling']?.landscapes, options['underling']!.landscapes);
    expect(rechecked['underling']?.setupChoices,
        options['underling']!.setupChoices);

    final backup = decodeKingdomBackup(encodeKingdomBackup([board]), catalogue);
    expect(backup.single.setupChoices, board.setupChoices);
    final shared = resolveSharedKingdom(
        encodeFullSetup(board),
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(shared.setupChoices, board.setupChoices);
    expect(shared.landscapeCards, unorderedEquals(board.landscapeCards));

    final banned = engine.generate(
      allCards: eligible,
      ownedExpansions: owned,
      rules: rules,
      lockedKingdomCards: main,
      excludedCardIds: {'forest_dwellers'},
      previousSetupChoices: board.setupChoices,
    );
    expect(banned.landscapeCards.map((card) => card.id), ['approaching_army']);
    expect(banned.setupChoices.containsKey('young_witch'), isFalse);
  });
}
