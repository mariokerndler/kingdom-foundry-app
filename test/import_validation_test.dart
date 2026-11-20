import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/translation_pack.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/providers/history_provider.dart';
import 'package:kingdom_foundry/providers/translation_provider.dart';

void main() {
  final catalogue =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((json) => KingdomCard.fromJson(json))
          .toList();
  final board = catalogue
      .where((card) =>
          card.isKingdomCard && !card.isDisabled && card.splitPileId == null)
      .take(9)
      .toList();
  board.add(catalogue.singleWhere((card) => card.id == 'young_witch'));

  test('rejects incomplete split piles even with ten unique slots', () {
    final half = catalogue.firstWhere((card) => card.splitPileId != null);
    expect(() => validateImportedKingdom(catalogue, [...board.take(9), half]),
        throwsFormatException);
  });

  test('accepts complete split piles counting as one slot', () {
    final pile =
        catalogue.firstWhere((card) => card.splitPileId != null).splitPileId;
    validateImportedKingdom(catalogue, [
      ...board.take(9),
      ...catalogue.where((card) => card.splitPileId == pile)
    ]);
  });

  for (final scenario in [
    'duplicates',
    'unknown',
    'version',
    'valid',
    'full setup',
    'text'
  ]) {
    testWidgets('import pipeline: $scenario', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      late WidgetRef ref;
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            allCardsProvider.overrideWith((ref) async => catalogue),
            translationPacksProvider.overrideWith((ref) async => [
                  TranslationPack(languageCode: 'de', label: 'Deutsch', cards: {
                    board.first.id: const CardTranslation(
                        name: 'Handwerker Test', text: ''),
                    'mission':
                        const CardTranslation(name: 'Auftrag Test', text: ''),
                  }),
                ]),
          ],
          child: Consumer(builder: (context, value, child) {
            ref = value;
            return const SizedBox();
          })));
      final ids = board.map((card) => card.id).toList();
      final text = scenario == 'full setup'
          ? encodeFullSetup(SetupResult(
              kingdomCards: board,
              archetypes: [],
              setupNotes: [],
              setupChoices: const {'young_witch': 'village'},
              rulesSnapshot: const SetupRules(showStrategyTips: false),
              playerCount: 4,
              generatedAt: DateTime(2025),
            ))
          : scenario == 'text'
              ? 'Handwerker Test\n${board.skip(1).map((card) => card.name).join('\n')}\n\nLandscapes:\n1. Auftrag Test'
              : scenario == 'duplicates'
                  ? List.generate(10, (i) => '${i + 1}. Village (\$3)')
                      .join('\n')
                  : SharePayload(
                      version: scenario == 'version' ? 99 : 1,
                      kingdomCardIds: [
                          ...ids,
                          if (scenario == 'unknown') 'missing_card'
                        ]).encode();
      final success = await tester.runAsync(() => importKingdom(ref, text));
      expect(success, ['valid', 'text', 'full setup'].contains(scenario));
      if (success == true) {
        expect(ref.read(setupResultProvider)!.kingdomSlotIds.length, 10);
        final saved =
            SetupResult.fromJson(ref.read(setupResultProvider)!.toJson());
        if (scenario == 'full setup') {
          expect(saved.setupChoices['young_witch'], 'village');
          expect(saved.playerCount, 4);
          expect(saved.rulesSnapshot?.showStrategyTips, isFalse);
          expect(ref.read(configProvider).playerCount, 2);
          ref.read(configProvider.notifier).useSetupSettings(
              rules: saved.rulesSnapshot!, playerCount: saved.playerCount!);
          expect(ref.read(configProvider).playerCount, 4);
          expect(ref.read(configProvider).rules.showStrategyTips, isFalse);
        } else {
          expect(saved.playerCount, isNull);
          expect(saved.rulesSnapshot, isNull);
        }
        if (scenario == 'text') {
          expect(ref.read(setupResultProvider)!.landscapeCards.single.name,
              'Mission');
        }
        expect(
            ref
                .read(setupResultProvider)!
                .setupNotes
                .any((note) => note.contains('Bane')),
            isTrue);
        expect(ref.read(historyProvider).history, hasLength(1));
        final archived = saved.copyWith(
          setupNotes: ['Outdated instructions'],
          savedName: 'Friday board',
          savedNotes: 'Try a thinner deck.',
          lockedSlotIds: {saved.kingdomCards.first.pileId},
          kingdomCards: [
            KingdomCard.fromJson({
              ...saved.kingdomCards.first.toJson(),
              'text': 'Old card effect'
            }),
            ...saved.kingdomCards.skip(1)
          ],
        );
        final opened = restoreKingdom(ref, archived);
        expect(opened.kingdomCards.first.text, saved.kingdomCards.first.text);
        expect(opened.savedName, archived.savedName);
        expect(opened.savedNotes, archived.savedNotes);
        expect(opened.lockedSlotIds, archived.lockedSlotIds);
        expect(opened.playerCount, archived.playerCount);
        expect(opened.rulesSnapshot, archived.rulesSnapshot);
        expect(opened.generatedAt, archived.generatedAt);
        expect(opened.setupChoices, archived.setupChoices);
        expect(archived.setupNotes, ['Outdated instructions']);
        expect(ref.read(setupResultProvider)!.setupNotes,
            isNot(contains('Outdated instructions')));
        expect(
            ref
                .read(setupResultProvider)!
                .setupNotes
                .any((note) => note.contains('Bane')),
            isTrue);
      } else {
        expect(ref.read(setupResultProvider), isNull);
        expect(ref.read(generationErrorProvider), isNotEmpty);
      }
    });
  }
}
