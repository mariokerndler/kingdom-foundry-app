import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/history_provider.dart';
import 'package:kingdom_foundry/services/history_service.dart';
import 'package:kingdom_foundry/widgets/common/history_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((value) => KingdomCard.fromJson(value as Map<String, dynamic>))
          .toList();
  final board = SetupResult(
    kingdomCards: catalogue
        .where((c) => c.isKingdomCard && !c.isDisabled && c.splitPileId == null)
        .take(10)
        .toList(),
    landscapeCards: [catalogue.firstWhere((c) => c.id == 'mission')],
    archetypes: const [],
    setupNotes: const ['Test setup choice'],
    rulesSnapshot: const SetupRules(requireDraw: true),
    playerCount: 4,
    generatedAt: DateTime(2026),
  );

  test(
      'backups keep settings and annotations, merge duplicate selections, and reject missing cards',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = HistoryService(await SharedPreferences.getInstance());
    await service.toggleFavorite(board);
    await service.editFavorite(board, '  Game night ', '  Try an engine.  ');
    final saved = service.loadFavorites().single;
    final backup = encodeKingdomBackup([saved]);
    expect(backup, isNot(contains('kingdomCards')));
    final restored = decodeKingdomBackup(backup, catalogue).single;
    expect(restored.savedName, 'Game night');
    expect(restored.savedNotes, 'Try an engine.');
    expect(restored.rulesSnapshot?.requireDraw, isTrue);
    expect(restored.playerCount, 4);
    expect(restored.setupNotes, ['Test setup choice']);
    expect(restored.selectionKey, board.selectionKey);

    final alternate = restored.copyWith(
      kingdomCards: restored.kingdomCards.reversed.toList(),
      generatedAt: DateTime(2026, 2),
      savedName: 'Keep the existing title',
    );
    await service.mergeFavorites([alternate]);
    expect(service.loadFavorites().single.savedName, 'Game night');
    expect(
      () => decodeKingdomBackup(
          backup, catalogue.where((c) => c.id != 'mission').toList()),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', contains('mission'))),
    );
  });

  test(
      'legacy favorites migrate to IDs and unavailable boards survive later saves',
      () async {
    final second = board.copyWith(landscapeCards: []);
    SharedPreferences.setMockInitialValues({
      'kingdom_favorites': jsonEncode([board.toJson(), second.toJson()]),
    });
    final prefs = await SharedPreferences.getInstance();
    final legacy = HistoryService(prefs, loadCatalogue: () async => catalogue);
    expect(legacy.loadFavorites(), hasLength(2));
    await legacy.editFavorite(board, 'Remember this board', '');
    expect(
        prefs.getString('kingdom_favorites'), isNot(contains('kingdomCards')));

    final incomplete = HistoryService(prefs,
        loadCatalogue: () async =>
            catalogue.where((card) => card.id != 'mission').toList());
    await incomplete.prepare();
    expect(incomplete.loadFavorites().single.selectionKey, second.selectionKey);
    expect(incomplete.hadUnreadableEntries, isTrue);
    await incomplete.editFavorite(second, 'Still available', '');

    final restored =
        HistoryService(prefs, loadCatalogue: () async => catalogue);
    await restored.prepare();
    expect(restored.loadFavorites().map((board) => board.savedName),
        unorderedEquals(['Remember this board', 'Still available']));
  });

  test('older backups restore Harem as the Farm pile and preserve its lock',
      () {
    final ids = ['harem', ...board.kingdomCards.skip(1).map((card) => card.id)];
    final restored = decodeKingdomBackup(
            jsonEncode({
              'version': 1,
              'kingdoms': [
                {
                  ...board.toJson(compact: true),
                  'kingdomCardIds': ids,
                  'lockedSlotIds': ['harem'],
                }
              ],
            }),
            catalogue)
        .single;
    expect(restored.kingdomSlotIds, hasLength(10));
    expect(restored.kingdomSlotIds, contains('farm'));
    expect(restored.lockedSlotIds, {'farm'});
  });

  test('compact saves preserve the original catalogue revision', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final first = HistoryService(prefs, loadCatalogue: () async => catalogue);
    await first.toggleFavorite(board);
    final originalRevision = first.loadFavorites().single.catalogueRevision;
    expect(originalRevision, matches(r'^v1-[0-9a-f]{8}$'));
    final changed = [
      for (final card in catalogue)
        if (card.id == board.kingdomCards.first.id)
          KingdomCard.fromJson({...card.toJson(), 'text': 'Updated text'})
        else
          card,
    ];
    final updated = HistoryService(prefs, loadCatalogue: () async => changed);
    await updated.prepare();
    final reopened = updated.loadFavorites().single;
    expect(reopened.kingdomCards.first.text, 'Updated text');
    expect(reopened.setupNotes, board.setupNotes);
    await updated.editFavorite(reopened, 'Updated name', '');
    await updated.push(board);

    final backup = encodeKingdomBackup(updated.loadFavorites());
    expect(decodeKingdomBackup(backup, changed).single.catalogueRevision,
        originalRevision);
    expect(updated.loadHistory().single.catalogueRevision,
        allOf(isNotNull, isNot(originalRevision)));
  });

  testWidgets('library edits a saved board and searches its notes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => catalogue),
    ]);
    addTearDown(container.dispose);
    await container.read(historyProvider.notifier).toggleFavorite(board);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: Consumer(
                  builder: (context, ref, _) => TextButton(
                      onPressed: () => showHistorySheet(context, ref),
                      child: const Text('Library'))))),
    ));
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit saved kingdom'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Friday board');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes'), 'Good for beginners');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Friday board'), findsOneWidget);
    final search = find.widgetWithText(TextField, 'Search saved kingdoms');
    await tester.enterText(search, 'beginners');
    await tester.pumpAndSettle();
    expect(find.text('Friday board'), findsOneWidget);
    await tester.enterText(search, 'does not match');
    await tester.pumpAndSettle();
    expect(find.text('No saved kingdoms match your search.'), findsOneWidget);
  });
}
