import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/table_setup_choice.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preview excludes attacks over the limit and handles Ally dependencies',
      () async {
    KingdomCard card(String id, List<CardType> types) => KingdomCard(
          id: id,
          name: id,
          expansion: Expansion.baseSecondEdition,
          types: types,
          tags: [],
          cost: 3,
          text: '',
        );
    final initial =
        List.generate(10, (index) => card('pile_$index', [CardType.action]));
    final liaison = card('liaison', [CardType.action, CardType.liaison]);
    final ally = card('ally', [CardType.ally]);
    final event = card('event', [CardType.event]);
    final attack = card('attack', [CardType.action, CardType.attack]);
    final catalogue = [...initial, liaison, ally, event, attack];
    final board = SetupResult(
        kingdomCards: initial,
        landscapeCards: [event],
        archetypes: [],
        setupNotes: [],
        rulesSnapshot: const SetupRules(maxAttacks: 0),
        generatedAt: DateTime(2026));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => catalogue),
      setupResultProvider.overrideWith((ref) => board),
    ]);
    addTearDown(container.dispose);
    final preview = await previewPileReplacements(container, 'pile_0');
    expect(preview.keys, ['liaison']);
    expect(preview['liaison']!.landscapes, [event, ally]);
    expect(container.read(setupResultProvider), same(board));
    expect(
        await rerollCurrentResult(container,
            replaceSlotId: 'pile_0', incomingSlotId: 'attack'),
        isFalse);
    expect(
        await rerollCurrentResult(container,
            replaceSlotId: 'pile_0', incomingSlotId: 'liaison'),
        isTrue);
    expect(container.read(setupResultProvider)!.landscapeCards, [event, ally]);

    final withAlly = container.read(setupResultProvider)!;
    container.read(setupResultProvider.notifier).state =
        withAlly.copyWith(lockedLandscapeIds: {'ally'});
    expect(await previewPileReplacements(container, 'liaison'), isEmpty);
    container.read(setupResultProvider.notifier).state = withAlly;
    expect(
        (await previewPileReplacements(container, 'liaison'))['pile_0']!
            .landscapes,
        [event]);
  });
  test(
      'replace changes one pile, preserves locks, and undo restores exact result',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cards = List.generate(
        11,
        (i) => KingdomCard(
            id: 'card_$i',
            name: 'Card $i',
            expansion: Expansion.baseSecondEdition,
            types: [CardType.action],
            tags: [],
            cost: 3,
            text: ''));
    final original = SetupEngine()
        .generate(
            allCards: cards.take(10).toList(),
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: const SetupRules())
        .copyWith(
      lockedSlotIds: {'card_1'},
      rulesSnapshot: const SetupRules(),
      playerCount: 4,
      platinumColonyChoice: TableSetupChoice.include,
      sheltersChoice: TableSetupChoice.exclude,
    );
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => cards),
      setupResultProvider.overrideWith((ref) => original),
    ]);
    addTearDown(container.dispose);
    container.read(configProvider.notifier).setRequireVillage(true);
    expect(
        await rerollCurrentResult(container, replaceSlotId: 'card_1'), isFalse);
    expect(container.read(setupResultProvider), same(original));
    expect(
        await rerollCurrentResult(container, replaceSlotId: 'card_0'), isTrue);
    final replaced = container.read(setupResultProvider)!;
    expect(
        replaced.kingdomSlotIds,
        {...original.kingdomSlotIds}
          ..remove('card_0')
          ..add('card_10'));
    expect(replaced.lockedSlotIds, {'card_1'});
    expect(replaced.rulesSnapshot?.requireVillage, isFalse);
    expect(replaced.playerCount, 4);
    expect(replaced.platinumColonyChoice, TableSetupChoice.include);
    expect(replaced.sheltersChoice, TableSetupChoice.exclude);
    expect(container.read(configProvider).rules.requireVillage, isTrue);
    expect(container.read(canUndoRerollProvider), isTrue);
    undoLastReroll(container);
    expect(container.read(setupResultProvider), same(original));
    expect(container.read(canUndoRerollProvider), isFalse);
    expect(await rerollCurrentResult(container), isTrue);
    final rerolled = container.read(setupResultProvider)!;
    expect(rerolled.platinumColonyChoice, TableSetupChoice.include);
    expect(rerolled.sheltersChoice, TableSetupChoice.exclude);
    undoLastReroll(container);
    expect(container.read(setupResultProvider), same(original));
  });
}
