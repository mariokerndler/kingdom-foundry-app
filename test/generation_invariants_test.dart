import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/controllers/setup_exception.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/card_tag.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cards =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .map((json) => KingdomCard.fromJson(json))
          .toList();
  final owned = cards.map((card) => card.expansion).toSet();

  test('real catalogue combined rules retain complete piles and attack cap',
      () {
    const rules = SetupRules(
        requireVillage: true,
        requireDraw: true,
        requireTrashing: true,
        requirePlusBuy: true,
        maxAttacks: 1,
        requireReactionIfAttacks: true);
    for (var seed = 0; seed < 40; seed++) {
      final result = SetupEngine(random: Random(seed))
          .generate(allCards: cards, ownedExpansions: owned, rules: rules);
      final ids = result.kingdomCards.map((card) => card.id).toSet();
      expect(result.kingdomSlotIds.length, 10, reason: 'seed $seed');
      final attacks = result.kingdomCards
          .where((card) => card.isAttack)
          .map((card) => card.splitPileId ?? card.id)
          .toSet();
      expect(attacks.length, lessThanOrEqualTo(1), reason: 'seed $seed');
      if (attacks.isNotEmpty) {
        expect(result.kingdomCards.any((card) => card.isReaction), isTrue);
      }
      for (final card
          in result.kingdomCards.where((card) => card.splitPileId != null)) {
        expect(
            ids,
            containsAll(cards
                .where((member) => member.splitPileId == card.splitPileId)
                .map((member) => member.id)));
      }
    }
  });

  test('forced attacks without an available reaction report a conflict', () {
    final board = cards
        .where((card) =>
            card.isKingdomCard &&
            !card.isDisabled &&
            card.splitPileId == null &&
            !card.isReaction)
        .take(10)
        .toList();
    expect(board.any((card) => card.isAttack), isTrue);
    expect(
        () => SetupEngine().generate(
            allCards: board,
            ownedExpansions: owned,
            rules: const SetupRules(requireReactionIfAttacks: true),
            lockedKingdomCards: board),
        throwsA(isA<SetupException>()));
  });

  test('pool count uses complete piles and updates when one member is banned',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final pairId =
        cards.firstWhere((card) => card.splitPileId != null).splitPileId;
    final pair = cards.where((card) => card.splitPileId == pairId).toList();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => pair),
    ]);
    addTearDown(container.dispose);
    container
        .read(configProvider.notifier)
        .selectAllExpansions({pair.first.expansion});
    await container.read(allCardsProvider.future);
    expect(container.read(selectedPoolCountProvider).requireValue, 1);
    container.read(configProvider.notifier).toggleCard(pair.first.id);
    expect(container.read(selectedPoolCountProvider).requireValue, 0);
    expect(container.read(allCardsProvider).requireValue, same(pair));
    expect(pair.every((card) => card.isKingdomCard), isTrue);
    container.read(configProvider.notifier).toggleCard(pair.first.id);
    expect(container.read(selectedPoolCountProvider).requireValue, 1);
  });

  test('preflight identifies a missing +Buy even with ten usable piles',
      () async {
    final eligible = cards.where(
        (card) => card.isKingdomCard && !card.isDisabled && !card.isSplitPile);
    final buy = eligible.firstWhere((card) => card.hasTag(CardTag.plusBuy));
    final pool = [
      ...eligible.where((card) => !card.hasTag(CardTag.plusBuy)).take(10),
      buy
    ];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => pool),
    ]);
    addTearDown(container.dispose);
    final config = container.read(configProvider.notifier);
    config.selectAllExpansions(pool.map((card) => card.expansion).toSet());
    config.setRequirePlusBuy(true);
    await container.read(allCardsProvider.future);
    expect(container.read(selectedPoolConflictProvider), isNull);
    config.toggleCard(buy.id);
    expect(container.read(selectedPoolCountProvider).requireValue, 10);
    expect(container.read(selectedPoolConflictProvider)?.message,
        contains('No permitted +Buy pile remains'));
  });
}
