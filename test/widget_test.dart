import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/card_tag.dart';
import 'package:kingdom_foundry/models/cost_curve_rule.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/game_vibe_preset.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/strategy_archetype.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/providers/history_provider.dart';
import 'package:kingdom_foundry/screens/configuration_screen.dart';
import 'package:kingdom_foundry/screens/results_screen.dart';
import 'package:kingdom_foundry/services/history_service.dart';
import 'package:kingdom_foundry/widgets/cards/kingdom_card_widget.dart';
import 'package:kingdom_foundry/widgets/screens/rules_section.dart';
import 'package:kingdom_foundry/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleArchetype = StrategyArchetype(
    kind: ArchetypeKind.bigMoney,
    headline: 'Big Money',
    description: 'Buy treasure and score points.',
    tips: ['Buy Silver early.'],
    keyCardNames: ['Market'],
    strength: 0.7,
  );

  KingdomCard sampleCard(int i) => KingdomCard(
        id: 'card_$i',
        name: 'Village $i',
        expansion: Expansion.baseSecondEdition,
        types: const [CardType.action],
        tags: const [CardTag.villageEffect, CardTag.plusAction],
        cost: 3 + (i % 3),
        text: 'Gain actions and keep your turn moving.',
      );

  final sampleCards = List.generate(10, sampleCard);

  final sampleResult = SetupResult(
    kingdomCards: sampleCards,
    archetypes: const [sampleArchetype],
    setupNotes: const ['Potion Supply pile present.'],
    generatedAt: DateTime(2026, 4, 11),
  );

  Future<void> pumpRulesTab(
    WidgetTester tester, {
    SetupRules rules = const SetupRules(),
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          configProvider.overrideWith(
            (ref) => ConfigNotifier(ref.watch(configPersistenceProvider))
              ..state = ConfigState(
                ownedExpansions: const {Expansion.baseSecondEdition},
                rules: rules,
                disabledCardIds: const {},
                playerCount: 2,
              ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RulesTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToCostCurve(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Prefer a cost curve'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('RulesTab cost curve editor', () {
    testWidgets('enabled cost curve reveals the editor', (tester) async {
      await pumpRulesTab(
        tester,
        rules: const SetupRules(
          costCurve: CostCurveRule(enabled: true),
        ),
      );

      await scrollToCostCurve(tester);
      expect(find.text('<=2'), findsOneWidget);
      expect(find.text('6+'), findsOneWidget);
    });

    testWidgets('inline validation appears when total is below 10',
        (tester) async {
      await pumpRulesTab(
        tester,
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 0,
            threeCount: 2,
            fourCount: 3,
            fiveCount: 3,
            sixPlusCount: 1,
          ),
        ),
      );

      await scrollToCostCurve(tester);
      expect(
        find.text('Finish assigning all 10 kingdom slots before generating.'),
        findsOneWidget,
      );
    });

    testWidgets('reset restores the default balanced curve', (tester) async {
      await pumpRulesTab(
        tester,
        rules: const SetupRules(
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 0,
            threeCount: 2,
            fourCount: 3,
            fiveCount: 3,
            sixPlusCount: 1,
          ),
        ),
      );

      final resetButton = find.widgetWithText(TextButton, 'Reset curve');
      await tester.scrollUntilVisible(
        resetButton,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(resetButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Finish assigning all 10 kingdom slots before generating.'),
        findsNothing,
      );
    });
  });

  group('Game vibe presets', () {
    testWidgets('tapping an active preset clears the vibe and resets preset rules',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      container.read(configProvider.notifier).state = const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(
              requireVillage: true,
              requireDraw: true,
              requireTrashing: true,
              maxAttacks: 1,
            ),
            disabledCardIds: {},
            playerCount: 2,
            selectedPresetId: 'engine_builder',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RulesTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preset active - tap again to remove vibe'), findsOneWidget);

      await tester.tap(find.text('Engine Builder'));
      await tester.pumpAndSettle();

      final updated = container.read(configProvider);
      expect(updated.selectedPresetId, GameVibePresets.noneId);
      expect(updated.rules.hasActiveRules, isFalse);
      expect(updated.rules.requireVillage, isFalse);
      expect(updated.rules.requireDraw, isFalse);
      expect(updated.rules.requireTrashing, isFalse);
      expect(updated.rules.maxAttacks, isNull);
    });
  });

  group('Strategy tips rule', () {
    testWidgets('rule toggle is shown and defaults to enabled', (tester) async {
      await pumpRulesTab(tester);

      await tester.scrollUntilVisible(
        find.text('Show strategy tips'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Show strategy tips'), findsOneWidget);
      expect(find.text('Hide strategy tips'), findsNothing);
    });

    testWidgets('results screen hides archetype tips when rule is off',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            configProvider.overrideWith(
              (ref) => ConfigNotifier(ref.watch(configPersistenceProvider))
                ..state = const ConfigState(
                  ownedExpansions: {Expansion.baseSecondEdition},
                  rules: SetupRules(showStrategyTips: false),
                  disabledCardIds: {},
                  playerCount: 2,
                ),
            ),
            setupResultProvider.overrideWith((ref) => sampleResult),
          ],
          child: const MaterialApp(
            home: ResultsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Strategy Guide'), findsNothing);
      expect(find.text('Big Money'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Potion Supply pile present.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Potion Supply pile present.'), findsOneWidget);
    });
  });

  group('Kingdom card interactions', () {
    testWidgets('tapping the lower area of a tall tile opens details',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 220,
                  child: KingdomCardWidget(
                    card: sampleCard(1),
                    index: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(KingdomCardWidget);
      final bottomTapPoint = tester.getBottomRight(cardFinder) - const Offset(90, 20);

      await tester.tapAt(bottomTapPoint);
      await tester.pumpAndSettle();

      expect(find.text('MECHANICS'), findsOneWidget);
    });
  });

  group('Theme mode', () {
    testWidgets('theme toggle is shown in the app bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            allCardsProvider.overrideWith((ref) async => sampleCards),
            availableExpansionsProvider.overrideWith(
              (ref) async => {Expansion.baseSecondEdition},
            ),
            expansionStatsProvider.overrideWith(
              (ref) async => {
                Expansion.baseSecondEdition:
                    (kingdom: sampleCards.length, landscape: 0),
              },
            ),
          ],
          child: const MaterialApp(
            home: ConfigurationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
      expect(find.byTooltip('Open kingdom library'), findsOneWidget);
      expect(find.byTooltip('Import kingdom'), findsOneWidget);
      expect(find.text('Current setup'), findsOneWidget);
    });

    testWidgets('app switches to dark theme when toggle is enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allCardsProvider.overrideWith((ref) async => sampleCards),
          availableExpansionsProvider.overrideWith(
            (ref) async => {Expansion.baseSecondEdition},
          ),
          expansionStatsProvider.overrideWith(
            (ref) async => {
              Expansion.baseSecondEdition:
                  (kingdom: sampleCards.length, landscape: 0),
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KingdomFoundryApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.light);

      await tester.tap(find.byTooltip('Switch to dark mode'));
      await tester.pump(const Duration(milliseconds: 300));

      final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(updatedApp.themeMode, ThemeMode.dark);
      expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    });
  });

  group('Responsive results layout', () {
    testWidgets('uses one-column layout at larger text scales', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            setupResultProvider.overrideWith((ref) => sampleResult),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const ResultsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Village 0'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));

      final cardZero = tester.getTopLeft(find.text('Village 0'));
      final cardOne = tester.getTopLeft(find.text('Village 1'));
      expect(cardZero.dx, equals(cardOne.dx));
      expect(find.text('Tap for details'), findsWidgets);
    });
  });

  group('Saved kingdom presets', () {
    testWidgets('results screen can save and unsave a preset', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            setupResultProvider.overrideWith((ref) => sampleResult),
          ],
          child: const MaterialApp(
            home: ResultsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Save kingdom preset'), findsOneWidget);

      await tester.tap(find.byTooltip('Save kingdom preset'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ResultsScreen)),
      );
      expect(container.read(historyProvider).favorites, hasLength(1));
      expect(find.byTooltip('Remove saved preset'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove saved preset'));
      await tester.pumpAndSettle();

      expect(container.read(historyProvider).favorites, isEmpty);
      expect(find.byTooltip('Save kingdom preset'), findsOneWidget);
    });

    test('history service keeps favorites when clearing history', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = HistoryService(prefs);

      await service.push(sampleResult);
      await service.toggleFavorite(sampleResult);
      await service.clearHistory();

      expect(service.loadHistory(), isEmpty);
      expect(service.loadFavorites(), hasLength(1));
    });
  });
}
