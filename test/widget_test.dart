import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/strategy_archetype.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/screens/configuration_screen.dart';
import 'package:kingdom_foundry/screens/results_screen.dart';
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

  final sampleResult = SetupResult(
    kingdomCards: [],
    archetypes: const [sampleArchetype],
    setupNotes: const ['Potion Supply pile present.'],
    generatedAt: DateTime(2026, 4, 11),
  );

  Future<void> pumpRulesTab(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
    await tester.pumpAndSettle();
  }

  Future<void> enableCostCurve(WidgetTester tester) async {
    await scrollToCostCurve(tester);
    await tester.tap(find.text('Prefer a cost curve'));
    await tester.pumpAndSettle();
  }

  Future<void> decrementCheapBucket(WidgetTester tester) async {
    final removeButtons = find.byIcon(Icons.remove_rounded);
    final firstCurveRemoveIndex = tester.widgetList(removeButtons).length - 5;
    await tester.tap(removeButtons.at(firstCurveRemoveIndex));
    await tester.pumpAndSettle();
  }

  group('RulesTab cost curve editor', () {
    testWidgets('enable switch reveals the editor', (tester) async {
      await pumpRulesTab(tester);

      expect(find.text('Assigned 10 / 10 slots'), findsNothing);

      await enableCostCurve(tester);

      expect(find.text('Assigned 10 / 10 slots'), findsOneWidget);
      expect(find.text('<=2'), findsOneWidget);
      expect(find.text('6+'), findsOneWidget);
    });

    testWidgets('inline validation appears when total is below 10',
        (tester) async {
      await pumpRulesTab(tester);

      await enableCostCurve(tester);
      await decrementCheapBucket(tester);

      expect(find.text('Assigned 9 / 10 slots'), findsOneWidget);
      expect(
        find.text('Finish assigning all 10 kingdom slots before generating.'),
        findsOneWidget,
      );
    });

    testWidgets('reset restores the default balanced curve', (tester) async {
      await pumpRulesTab(tester);

      await enableCostCurve(tester);
      await decrementCheapBucket(tester);

      expect(find.text('Assigned 9 / 10 slots'), findsOneWidget);

      await tester.tap(find.text('Reset curve'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned 10 / 10 slots'), findsOneWidget);
      expect(
        find.text('Finish assigning all 10 kingdom slots before generating.'),
        findsNothing,
      );
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
      await tester.pumpAndSettle();

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
      expect(find.text('Potion Supply pile present.'), findsOneWidget);
    });
  });

  group('Theme mode', () {
    testWidgets('theme toggle is shown in the app bar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: ConfigurationScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
    });

    testWidgets('app switches to dark theme when toggle is enabled',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
}
