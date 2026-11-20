import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/collection_profile.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/teaching_kingdom.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/screens/configuration_screen.dart';
import 'package:kingdom_foundry/screens/results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((value) => KingdomCard.fromJson(value as Map<String, dynamic>))
          .toList();

  test(
      'teaching sets resolve to valid boards and respect the collection and bans',
      () {
    const config = ConfigState(
        ownedExpansions: {
          Expansion.baseSecondEdition,
          Expansion.intrigueSecondEdition
        },
        rules: SetupRules(),
        disabledCardIds: {},
        activeCollection: 'Both printings',
        collections: {
          'Both printings': CollectionProfile(
            boxes: {
              Expansion.baseSecondEdition: CollectionEdition.upgraded,
              Expansion.intrigueSecondEdition: CollectionEdition.full,
            },
            promoPiles: {},
            selected: {
              Expansion.baseSecondEdition,
              Expansion.intrigueSecondEdition
            },
          ),
          'Original': CollectionProfile(
            boxes: {
              Expansion.baseSecondEdition: CollectionEdition.firstEdition
            },
            promoPiles: {},
            selected: {Expansion.baseSecondEdition},
          ),
        });
    for (final board in teachingKingdoms) {
      expect(resolveTeachingKingdom(board, catalogue, config), hasLength(10),
          reason: board.name);
    }
    final banned = config.copyWith(disabledCardIds: {'market'});
    expect(resolveTeachingKingdom(teachingKingdoms.first, catalogue, banned),
        isNull);
    final baseOnly =
        config.copyWith(ownedExpansions: {Expansion.baseSecondEdition});
    expect(resolveTeachingKingdom(teachingKingdoms.last, catalogue, baseOnly),
        isNull);
    final original = baseOnly.copyWith(activeCollection: 'Original');
    final originalBoard = teachingKingdoms
        .singleWhere((board) => board.name == 'First Game (1st Ed.)');
    expect(resolveTeachingKingdom(teachingKingdoms.first, catalogue, original),
        isNull);
    expect(
        resolveTeachingKingdom(originalBoard, catalogue, original)
            ?.map((card) => card.id),
        contains('woodcutter'));
  });

  test('freshness reduces repeats while preserving bans, locks and attack caps',
      () {
    const rules = SetupRules(maxAttacks: 0);
    final recent = {...teachingKingdoms.first.cardIds, 'chapel'};
    final locked = catalogue.singleWhere((card) => card.id == 'chapel');
    final cards = catalogue
        .map((card) =>
            card.id == 'artisan' ? card.copyWith(isDisabled: true) : card)
        .toList();
    var usualRepeats = 0;
    var freshRepeats = 0;
    for (var seed = 0; seed < 8; seed++) {
      final usual = SetupEngine(random: Random(seed)).generate(
          allCards: cards,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: rules,
          lockedKingdomCards: [locked]);
      final fresh = SetupEngine(random: Random(seed)).generate(
          allCards: cards,
          ownedExpansions: {Expansion.baseSecondEdition},
          rules: rules,
          lockedKingdomCards: [locked],
          recentSlots: recent);
      usualRepeats += usual.kingdomSlotIds.intersection(recent).length;
      freshRepeats += fresh.kingdomSlotIds.intersection(recent).length;
      expect(fresh.kingdomSlotIds, hasLength(10));
      expect(fresh.kingdomSlotIds, contains('chapel'));
      expect(fresh.kingdomSlotIds, isNot(contains('artisan')));
      expect(fresh.hasAttacks, isFalse);
    }
    expect(freshRepeats, lessThan(usualRepeats));
  });

  testWidgets(
      'first-game menu opens the fixed board without changing saved rules',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => catalogue),
      availableExpansionsProvider
          .overrideWith((ref) async => {Expansion.baseSecondEdition}),
    ]);
    addTearDown(container.dispose);
    container.read(configProvider.notifier).setNoAttacks(true);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConfigurationScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First game'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your first game'), findsOneWidget);
    expect(find.text('Grand Scheme'), findsNothing);
    expect(find.text('First Game (1st Ed.)'), findsNothing);
    expect(find.text('Roll Beginner Friendly'), findsOneWidget);
    await tester.tap(find.text('First Game'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(container.read(setupResultProvider)!.kingdomSlotIds,
        teachingKingdoms.first.cardIds.toSet());
    expect(container.read(configProvider).rules.noAttacks, isTrue);

    container.read(configProvider.notifier).setPreferFreshPiles(true);
    Navigator.of(tester.element(find.byType(ResultsScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('First game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roll Beginner Friendly'));
    await tester.pumpAndSettle();
    final beginner = container.read(setupResultProvider)!;
    expect(beginner.presetId, 'beginner_friendly');
    expect(beginner.rulesSnapshot?.maxAttacks, 1);
    expect(
        beginner.selectionRationale.join(' '), contains('last three boards'));
    expect(container.read(configProvider).rules.noAttacks, isTrue);
  });
}
