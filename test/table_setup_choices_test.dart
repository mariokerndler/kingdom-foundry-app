import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/table_checklist.dart';
import 'package:kingdom_foundry/models/table_setup_choice.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/providers/history_provider.dart';
import 'package:kingdom_foundry/screens/results_screen.dart';
import 'package:kingdom_foundry/services/history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((raw) => KingdomCard.fromJson(raw as Map<String, dynamic>))
          .toList();
  final byId = {for (final card in catalogue) card.id: card};
  final cards = [
    'village',
    'smithy',
    'market',
    'festival',
    'laboratory',
    'chapel',
    'moat',
    'militia',
    'merchant',
    'cellar'
  ].map((id) => byId[id]!).toList();
  final board = SetupResult(
      kingdomCards: cards,
      archetypes: [],
      setupNotes: [],
      playerCount: 2,
      generatedAt: DateTime(2026));

  test('table choices round-trip all states and reject malformed stored values',
      () {
    for (final platinum in TableSetupChoice.values) {
      for (final shelters in TableSetupChoice.values) {
        final chosen = board.copyWith(
            platinumColonyChoice: platinum, sheltersChoice: shelters);
        final restored = [
          SetupResult.fromJson(chosen.toJson()),
          SetupResult.fromJson(chosen.toJson(compact: true), catalogue: byId),
          decodeKingdomBackup(encodeKingdomBackup([chosen]), catalogue).single,
          resolveSharedKingdom(
              encodeFullSetup(chosen),
              catalogue,
              const ConfigState(
                  ownedExpansions: {},
                  rules: SetupRules(),
                  disabledCardIds: {})),
        ];
        for (final result in restored) {
          expect(result.platinumColonyChoice, platinum);
          expect(result.sheltersChoice, shelters);
        }
      }
    }
    expect(SetupResult.fromJson(board.toJson()).sheltersChoice,
        TableSetupChoice.undecided);
    expect(SharePayload.fromJson({'k': []}).platinumColonyChoice,
        TableSetupChoice.undecided);
    for (final invalid in [true, 1, 'yes', [], {}]) {
      expect(
          () => SetupResult.fromJson(
              {...board.toJson(), 'sheltersChoice': invalid}),
          throwsFormatException);
      expect(
          () => SharePayload.fromJson({'pc': invalid}), throwsFormatException);
    }
  });

  test('checklists use chosen quantities and replace undecided instructions',
      () {
    final mixed = [...cards.take(8), byId['watchtower']!, byId['hermit']!];
    final undecided = board.copyWith(
        kingdomCards: mixed,
        setupNotes: SetupEngine().generateSetupNotes(mixed, []));
    expect(
        tableChecklist(undecided, 2).join(' '), contains('if using Platinum'));
    expect(tableChecklist(undecided, 2).join(' '), contains('decide whether'));
    final chosen = undecided.copyWith(
        platinumColonyChoice: TableSetupChoice.include,
        sheltersChoice: TableSetupChoice.include);
    for (final players in [2, 3, 5, 6]) {
      final text = tableChecklist(chosen, players).join(' ');
      final victory = players == 2 ? 8 : 12;
      expect(text, contains('12 Platinums and $victory Colonies'));
      expect(
          text, contains('one Hovel, one Necropolis and one Overgrown Estate'));
      expect(text, contains('Estate Supply still contains $victory Estates'));
      expect(text, contains('empty Colony pile also ends the game'));
      expect(text, isNot(contains('if using Platinum')));
      expect(text, isNot(contains('decide whether')));
      expect(text, isNot(contains('give each player 7 Coppers and 3 Estates')));
    }
    final excluded = chosen.copyWith(
        platinumColonyChoice: TableSetupChoice.exclude,
        sheltersChoice: TableSetupChoice.exclude);
    final text = tableChecklist(excluded, 2).join(' ');
    expect(text, contains('Platinum and Colony: not used.'));
    expect(text, contains('Shelters: not used.'));
    expect(text, contains('give each player 7 Coppers and 3 Estates'));
    expect(text, isNot(contains('if using Platinum')));
    expect(text, isNot(contains('decide whether')));
  });

  test(
      'library updates matching choices without duplicates or lost annotations',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = HistoryService(prefs, loadCatalogue: () async => catalogue);
    await service.push(board);
    await service.toggleFavorite(
        board.copyWith(savedName: 'Friday', savedNotes: 'Keep me'));
    final other = board.copyWith(generatedAt: DateTime(2026, 1, 2));
    await service.push(other);
    final chosen = board.copyWith(
        platinumColonyChoice: TableSetupChoice.include,
        sheltersChoice: TableSetupChoice.exclude);
    await service.updateTableChoices(chosen);
    final reloaded =
        HistoryService(prefs, loadCatalogue: () async => catalogue);
    await reloaded.prepare();
    expect(reloaded.loadHistory(), hasLength(2));
    expect(reloaded.loadHistory().first.platinumColonyChoice,
        TableSetupChoice.undecided);
    expect(reloaded.loadHistory().last.platinumColonyChoice,
        TableSetupChoice.include);
    final saved = reloaded.loadFavorites().single;
    expect(saved.platinumColonyChoice, TableSetupChoice.include);
    expect(saved.sheltersChoice, TableSetupChoice.exclude);
    expect(saved.savedName, 'Friday');
    expect(saved.savedNotes, 'Keep me');
    await reloaded.updateTableChoices(board);
    expect(reloaded.loadFavorites().single.sheltersChoice,
        TableSetupChoice.undecided);
  });

  testWidgets('table setup previews, cancels and saves both choices',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => catalogue),
      setupResultProvider.overrideWith((ref) => board),
    ]);
    addTearDown(container.dispose);
    await container.read(historyProvider.notifier).push(board);
    await container.read(historyProvider.notifier).toggleFavorite(board);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: ResultsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Table setup'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byType(DropdownButtonFormField<TableSetupChoice>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('12 Platinums and 8 Colonies'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(container.read(setupResultProvider)!.platinumColonyChoice,
        TableSetupChoice.undecided);
    await tester.tap(find.text('Table setup'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester
          .tap(find.byType(DropdownButtonFormField<TableSetupChoice>).at(i));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use').last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(container.read(setupResultProvider)!.platinumColonyChoice,
        TableSetupChoice.include);
    expect(container.read(setupResultProvider)!.sheltersChoice,
        TableSetupChoice.include);
    expect(container.read(historyProvider).favorites.single.sheltersChoice,
        TableSetupChoice.include);
    expect(container.read(historyProvider).history.single.platinumColonyChoice,
        TableSetupChoice.include);
    await tester.tap(find.byTooltip('Kingdom actions'));
    await tester.pumpAndSettle();
    expect(find.text('Copy full setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
