import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kingdom_foundry/models/cost_curve_rule.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/services/config_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigPersistenceService', () {
    test('round-trips enabled cost curve settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ConfigPersistenceService(prefs);

      const state = ConfigState(
        ownedExpansions: {Expansion.baseSecondEdition, Expansion.intrigue},
        rules: SetupRules(
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

    test('round-trips hidden strategy tips setting', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ConfigPersistenceService(prefs);

      const state = ConfigState(
        ownedExpansions: {Expansion.baseSecondEdition},
        rules: SetupRules(showStrategyTips: false),
        disabledCardIds: {},
        playerCount: 2,
      );

      await service.save(state);
      final loaded = service.load();

      expect(loaded.rules.showStrategyTips, isFalse);
    });
  });
}
