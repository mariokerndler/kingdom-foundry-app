import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/translation_pack.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/translation_provider.dart';
import 'package:kingdom_foundry/widgets/screens/card_ban_list.dart';
import 'package:kingdom_foundry/widgets/cards/kingdom_card_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('exchange links use IDs after renames and retain legacy lookup',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    KingdomCard card(String id, String name, {bool legacy = false}) =>
        KingdomCard(
          id: id,
          name: name,
          expansion: Expansion.adventures,
          types: [CardType.action],
          tags: [],
          cost: 2,
          text: 'English rules',
          travellerChain: id == 'base' ? ['Old name'] : [],
          travellerChainIds: id == 'base' && !legacy ? ['upgrade'] : [],
        );
    final upgrade = card('upgrade', 'Renamed upgrade');
    final oldUpgrade = card('old_upgrade', 'Old name');
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => [upgrade, oldUpgrade]),
      activeTranslationPackProvider.overrideWith((ref) => const AsyncData(
            TranslationPack(languageCode: 'de', label: 'Deutsch', cards: {
              'upgrade':
                  CardTranslation(name: 'Neue Karte', text: 'Neue Regeln'),
            }),
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => KingdomCardWidget.showDetails(
                          context, card('base', 'Base')),
                      child: const Text('Open'))))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Neue Karte'));
    expect(find.text('Neue Regeln'), findsOneWidget);
    expect(find.text('Old name'), findsNothing);
    await tester.tap(find.text('Neue Karte'));
    await tester.pumpAndSettle();
    expect(find.text('Neue Karte'), findsNWidgets(2));
    expect(find.text('Neue Regeln'), findsNWidgets(2));
    Navigator.of(tester.element(find.text('Neue Karte').last)).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Neue Karte'))).pop();
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Open'));
    KingdomCardWidget.showDetails(
        context, card('base', 'Legacy', legacy: true));
    await tester.pumpAndSettle();
    expect(find.text('Old name'), findsOneWidget);
  });

  testWidgets('catalogue finds translated rules and bans a whole split pile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cards = ['top', 'bottom']
        .map((id) => KingdomCard(
              id: id,
              name: id,
              expansion: Expansion.baseSecondEdition,
              types: [CardType.action],
              tags: [],
              cost: 2,
              text: 'Draw a card.',
              splitPileId: 'test_pile',
            ))
        .toList();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      allCardsProvider.overrideWith((ref) async => cards),
      activeTranslationPackProvider.overrideWith((ref) => const AsyncData(
            TranslationPack(languageCode: 'de', label: 'Deutsch', cards: {
              'top': CardTranslation(name: 'Oben', text: 'Ziehe eine Karte.'),
            }),
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: CardBanListTab())),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ziehe');
    await tester.pumpAndSettle();
    expect(find.text('Oben'), findsOneWidget);
    expect(find.text('bottom'), findsNothing);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any coin cost'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 coins'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Oben'), findsOneWidget);
    await tester.tap(find.byTooltip('Ban whole pile'));
    await tester.pumpAndSettle();
    expect(container.read(configProvider).disabledCardIds, {'top', 'bottom'});
    await tester.tap(find.text('Oben'));
    await tester.pumpAndSettle();
    expect(find.text('Ziehe eine Karte.'), findsOneWidget);
    expect(find.text('bottom'), findsOneWidget);
  });
}
