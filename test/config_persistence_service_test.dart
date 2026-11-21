import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingdom_foundry/models/cost_curve_rule.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/services/config_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rapid saves persist the latest complete settings', () async {
    SharedPreferences.setMockInitialValues({});
    final service =
        ConfigPersistenceService(await SharedPreferences.getInstance());
    final initial = service.load();
    final saves = List.generate(
        20,
        (index) => service.save(initial.copyWith(
              playerCount: index.isEven ? 2 : 4,
              rules: SetupRules(maxCost: index.isEven ? 5 : null),
              disabledCardIds: {'card_$index'},
            )));
    await Future.wait(saves);
    final restored = service.load();
    expect(restored.playerCount, 4);
    expect(restored.rules.maxCost, isNull);
    expect(restored.disabledCardIds, {'card_19'});
  });

  test(
      'damaged preferences recover independently without deleting valid settings',
      () async {
    SharedPreferences.setMockInitialValues({
      'cfg_expansions': '{broken',
      'cfg_disabled_cards': '{broken',
      'cfg_cost_curve': '{broken',
      'cfg_no_attacks': 'wrong type',
      'cfg_player_count': 99,
      'cfg_use_dark_mode': true,
      'cfg_require_buy': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = ConfigPersistenceService(prefs).load();
    expect(state.ownedExpansions, {Expansion.baseSecondEdition});
    expect(state.disabledCardIds, isEmpty);
    expect(state.rules.costCurve.enabled, isFalse);
    expect(state.rules.noAttacks, isFalse);
    expect(state.playerCount, 6);
    expect(state.useDarkMode, isTrue);
    expect(state.rules.requirePlusBuy, isTrue);
    expect(prefs.getString('cfg_expansions'), '{broken');
  });

  test('explicitly empty collection stays empty', () async {
    SharedPreferences.setMockInitialValues({'cfg_expansions': '[]'});
    final state =
        ConfigPersistenceService(await SharedPreferences.getInstance()).load();
    expect(state.ownedExpansions, isEmpty);
  });

  test('legacy Harem bans keep the current Farm pile banned', () async {
    SharedPreferences.setMockInitialValues({
      'cfg_disabled_cards': '["harem"]',
    });
    final service =
        ConfigPersistenceService(await SharedPreferences.getInstance());
    expect(service.load().disabledCardIds, {'farm'});
  });

  test('snapshot migrates legacy settings and bounds damaged numeric values',
      () async {
    SharedPreferences.setMockInitialValues({
      'cfg_require_draw': true,
      'cfg_max_attacks': -25,
      'cfg_max_cost': 20,
      'cfg_landscape_events': -2,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = ConfigPersistenceService(prefs);
    final legacy = service.load();
    expect(legacy.rules.maxAttacks, 0);
    expect(legacy.rules.maxCost, 8);
    expect(legacy.rules.landscapeEvents, 0);
    await service.save(
        legacy.copyWith(rules: legacy.rules.copyWith(minExpansionVariety: 3)));
    await prefs.setBool('cfg_require_draw', false);
    final restored = ConfigPersistenceService(prefs).load();
    expect(restored.rules.requireDraw, isTrue);
    expect(restored.rules.minExpansionVariety, 3);
  });

  test('reset all removes preset scoring as well as rules', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = ConfigNotifier(ConfigPersistenceService(prefs));
    addTearDown(notifier.dispose);
    notifier.setSelectedPresetId('engine_builder');
    notifier.resetRules();
    expect(notifier.state.selectedPresetId, 'none');
    expect(notifier.state.rules.hasActiveRules, isFalse);
  });

  test('removing a vibe resets rules while keeping display preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = ConfigNotifier(ConfigPersistenceService(prefs));
    addTearDown(notifier.dispose);

    notifier.setSelectedPresetId('engine_builder');
    notifier.setMaxAttacks(0);
    notifier.setIncludeLandscape(false);
    notifier.setShowStrategyTips(false);
    final customRules = notifier.state.rules;
    notifier.setSelectedPresetId('none');
    expect(notifier.state.selectedPresetId, 'none');
    expect(
        notifier.state.rules.toJson(),
        const SetupRules(includeLandscape: false, showStrategyTips: false)
            .toJson());

    notifier.setSelectedPresetId('engine_builder');
    expect(notifier.state.rules.maxAttacks, isNull);
    notifier.restoreRules(customRules, 'engine_builder');
    expect(notifier.state.rules.maxAttacks, 0);
  });

  group('ConfigPersistenceService', () {
    test('round-trips enabled cost curve settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ConfigPersistenceService(prefs);

      const state = ConfigState(
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.intrigue},
        rules: SetupRules(
          noHighSetup: true,
          costCurve: CostCurveRule(
            enabled: true,
            cheapCount: 2,
            threeCount: 1,
            fourCount: 3,
            fiveCount: 2,
            sixPlusCount: 2,
          ),
        ),
        disabledCardIds: {'witch'},
        playerCount: 3,
        useDarkMode: true,
      );

      await service.save(state);
      final loaded = service.load();

      expect(loaded.rules.costCurve.enabled, isTrue);
      expect(loaded.rules.noHighSetup, isTrue);
      expect(loaded.rules.showStrategyTips, isTrue);
      expect(loaded.rules.costCurve.bucketCounts, {
        '<=2': 2,
        '3': 1,
        '4': 3,
        '5': 2,
        '6+': 2,
      });
      expect(loaded.ownedExpansions, state.ownedExpansions);
      expect(loaded.disabledCardIds, state.disabledCardIds);
      expect(loaded.playerCount, 3);
      expect(loaded.useDarkMode, isTrue);
    });

    test('round-trips strategy tips and freshness preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ConfigPersistenceService(prefs);

      const state = ConfigState(
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: SetupRules(showStrategyTips: false),
        disabledCardIds: {},
        playerCount: 2,
        preferFreshPiles: true,
      );

      await service.save(state);
      final loaded = service.load();

      expect(loaded.rules.showStrategyTips, isFalse);
      expect(loaded.preferFreshPiles, isTrue);
    });
  });
}
