import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/collection_profile.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/table_checklist.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/services/config_persistence_service.dart';
import 'package:kingdom_foundry/widgets/screens/expansion_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((json) => KingdomCard.fromJson(json as Map<String, dynamic>))
          .toList();
  final allById = {for (final card in catalogue) card.id: card};

  test('update-pack IDs belong to the canonical expansion', () {
    for (final entry in updatePackCards.entries) {
      for (final id in entry.value) {
        expect(allById[id]?.expansion, entry.key, reason: id);
      }
    }
  });

  test('original profiles include their retired piles', () {
    const editions = {
      Expansion.baseSecondEdition: {
        'adventurer',
        'chancellor',
        'feast',
        'spy',
        'thief',
        'woodcutter'
      },
      Expansion.intrigueSecondEdition: {
        'coppersmith',
        'great_hall',
        'saboteur',
        'scout',
        'secret_chamber',
        'tribute'
      },
      Expansion.seasideSecondEdition: {
        'ambassador',
        'embargo',
        'explorer',
        'ghost_ship',
        'navigator',
        'pearl_diver',
        'pirate_ship',
        'sea_hag',
      },
      Expansion.prosperitySecondEdition: {
        'contraband',
        'counting_house',
        'goons',
        'loan',
        'mountebank',
        'royal_seal',
        'talisman',
        'trade_route',
        'venture',
      },
      Expansion.hinterlandsSecondEdition: {
        'cache',
        'duchess',
        'embassy',
        'ill_gotten_gains',
        'mandarin',
        'noble_brigand',
        'nomad_camp',
        'oracle',
        'silk_road',
      },
      Expansion.cornucopiaGuildsSecondEdition: {
        'farming_village',
        'fortune_teller',
        'harvest',
        'horse_traders',
        'tournament',
        'doctor',
        'masterpiece',
        'taxman',
      },
    };
    const countsByExpansion = {
      Expansion.baseSecondEdition: (first: 25, second: 26, pack: 7),
      Expansion.intrigueSecondEdition: (first: 25, second: 26, pack: 7),
      Expansion.seasideSecondEdition: (first: 26, second: 27, pack: 9),
      Expansion.prosperitySecondEdition: (first: 25, second: 25, pack: 9),
      Expansion.hinterlandsSecondEdition: (first: 26, second: 26, pack: 9),
      Expansion.cornucopiaGuildsSecondEdition: (first: 26, second: 26, pack: 8),
    };
    for (final entry in editions.entries) {
      final (first: first, second: second, pack: pack) =
          countsByExpansion[entry.key]!;
      final counts = {
        CollectionEdition.firstEdition: first,
        CollectionEdition.full: second,
        CollectionEdition.updatePack: pack,
        CollectionEdition.upgraded: first + pack,
      };
      final box = catalogue
          .where((card) => card.expansion == entry.key && card.isKingdomCard);
      expect(box.where((card) => card.firstEditionOnly).map((card) => card.id),
          unorderedEquals(entry.value));
      for (final count in counts.entries) {
        final profile = CollectionProfile(
            boxes: {entry.key: count.key},
            promoPiles: {},
            selected: {entry.key});
        final owned =
            box.where(profile.owns).map((card) => card.pileId).toSet();
        expect(owned, hasLength(count.value));
        final includeRetired = count.key == CollectionEdition.firstEdition ||
            count.key == CollectionEdition.upgraded;
        if (includeRetired) {
          expect(owned, containsAll(entry.value));
        } else {
          expect(owned.intersection(entry.value), isEmpty);
        }
      }
    }
    final retired = allById['woodcutter']!;
    final board = SetupResult(
      kingdomCards: [
        retired,
        ...catalogue
            .where((card) =>
                card.expansion == Expansion.baseSecondEdition &&
                !card.firstEditionOnly)
            .take(9),
      ],
      archetypes: [],
      setupNotes: [],
      generatedAt: DateTime(2026),
    );
    final code = encodeSharePayload(board);
    expect(code, startsWith(SharePayload.prefix));
    expect(SharePayload.tryDecodeAny(code, catalogue)?.kingdomCardIds,
        contains(retired.id));
    final restored = resolveSharedKingdom(
        code,
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(restored.kingdomSlotIds, board.kingdomSlotIds);
  });

  test('Tournament Prizes and Joust Rewards use separate setup and ownership',
      () {
    final tournament = allById['tournament']!;
    final joust = allById['joust']!;
    const expansion = Expansion.cornucopiaGuildsSecondEdition;
    const original = CollectionProfile(
      boxes: {expansion: CollectionEdition.firstEdition},
      promoPiles: {},
      selected: {expansion},
    );
    final prizes = tournament.pileCardIds.map((id) => allById[id]!).toList();
    final rewards = joust.pileCardIds.map((id) => allById[id]!).toList();
    expect(prizes, hasLength(5));
    expect(rewards, hasLength(6));
    for (final prize in prizes) {
      expect(prize.isAuxiliary, isTrue);
      expect(prize.types, contains(CardType.prize));
      expect(prize.printedExpansion, Expansion.cornucopia);
      expect(original.owns(prize), isTrue);
    }
    expect(rewards.where(original.owns), isEmpty);
    final result = SetupResult(
      kingdomCards: [tournament, joust],
      archetypes: [],
      setupNotes: SetupEngine().generateSetupNotes([tournament, joust], []),
      generatedAt: DateTime(2026),
    );
    expect(result.setupNotes.join(' '), contains('Trusty Steed as Prizes'));
    expect(result.setupNotes.join(' '), contains('Coffers mats'));
    expect(tableChecklist(result, 2).join(' '),
        contains('one copy of each Reward'));
    expect(tableChecklist(result, 3).join(' '),
        contains('two copies of each Reward'));
  });

  test('first-edition setup lists the mats and tokens used by the board', () {
    final selected = [
      for (final id in [
        'embargo',
        'pirate_ship',
        'trade_route',
        'goons',
        'silk_road'
      ])
        allById[id]!,
    ];
    final notes = SetupEngine().generateSetupNotes(selected, []).join(' ');
    expect(notes, contains('set out the Embargo tokens'));
    expect(notes, contains('one Pirate Ship mat per player'));
    expect(notes, contains('one Coin token on each Victory Supply pile'));
    expect(notes, contains('prepare the Victory Point token supply'));
    expect(allById['silk_road']!.isVictory, isTrue);
    expect(allById['pirate_ship']!.printedExpansion, Expansion.seaside);
  });

  test('profiles keep independent selections and reuse edition and promo IDs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => catalogue),
    ]);
    addTearDown(container.dispose);
    final config = container.read(configProvider.notifier);
    await container.read(allCardsProvider.future);
    config.saveCollection(
        'Travel box',
        const CollectionProfile(
          boxes: {Expansion.baseSecondEdition: CollectionEdition.updatePack},
          promoPiles: {'promos_sauna_avanto'},
          selected: {Expansion.baseSecondEdition, Expansion.promos},
        ));
    final travel = container.read(selectedKingdomPoolProvider).requireValue;
    expect(container.read(selectedPoolCountProvider).requireValue, 8);
    expect(travel.map((card) => card.id),
        containsAll(['sauna', 'avanto', 'artisan']));
    expect(travel.map((card) => card.id), isNot(contains('village')));
    expect(travel.map((card) => card.id), isNot(contains('black_market')));
    config.toggleExpansion(Expansion.promos);
    expect(container.read(configProvider).collection!.promoPiles,
        {'promos_sauna_avanto'});
    expect(container.read(selectedPoolCountProvider).requireValue, 7);

    config.saveCollection(
        'Home',
        const CollectionProfile(
          boxes: {Expansion.baseSecondEdition: CollectionEdition.upgraded},
          promoPiles: {'summon'},
          selected: {Expansion.baseSecondEdition, Expansion.promos},
        ));
    expect(container.read(selectedPoolCountProvider).requireValue, 32);
    config.saveCollection(
        'Original',
        const CollectionProfile(
          boxes: {Expansion.baseSecondEdition: CollectionEdition.firstEdition},
          promoPiles: {},
          selected: {Expansion.baseSecondEdition},
        ));
    final original = container.read(selectedKingdomPoolProvider).requireValue;
    expect(container.read(selectedPoolCountProvider).requireValue, 25);
    expect(original.map((card) => card.id), contains('woodcutter'));
    expect(original.map((card) => card.id), isNot(contains('artisan')));
    config.selectCollection('Travel box');
    expect(container.read(selectedPoolCountProvider).requireValue, 7);
    await container
        .read(configPersistenceProvider)
        .save(container.read(configProvider));
    final restarted = ConfigNotifier(ConfigPersistenceService(prefs));
    addTearDown(restarted.dispose);
    expect(restarted.state.activeCollection, 'Travel box');
    restarted.selectCollection('');
    expect(restarted.state.ownedExpansions, {Expansion.baseSecondEdition});
    expect(restarted.state.excludedCardIds(catalogue), contains('woodcutter'));
    restarted.selectCollection('Home');
    expect(restarted.state.collection!.promoPiles, {'summon'});
  });

  testWidgets('expansion picker saves a named collection with one promo pile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async =>
          [allById['artisan']!, allById['sauna']!, allById['avanto']!]),
      availableExpansionsProvider.overrideWith(
          (ref) async => {Expansion.baseSecondEdition, Expansion.promos}),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ExpansionPickerTab()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Friday group');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sauna / Avanto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save collection'));
    await tester.pumpAndSettle();
    expect(find.text('Friday group'), findsOneWidget);
    expect(container.read(configProvider).collection?.promoPiles,
        {'promos_sauna_avanto'});
    expect(container.read(configProvider).ownedExpansions,
        {Expansion.baseSecondEdition, Expansion.promos});
    expect(tester.takeException(), isNull);
  });
}
