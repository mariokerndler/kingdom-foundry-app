import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/models/cost_curve_rule.dart';

void main() {
  group('CostCurveRule', () {
    test('default curve is valid and balanced', () {
      const rule = CostCurveRule(enabled: true);

      expect(rule.totalSlots, CostCurveRule.targetSlotCount);
      expect(rule.isValid, isTrue);
      expect(
        rule.targetDescription,
        equals('Cost curve: <=2:1, 3:2, 4:3, 5:3, 6+:1'),
      );
    });

    test('disabled curve is treated as valid even when incomplete', () {
      const rule = CostCurveRule(
        enabled: false,
        cheapCount: 0,
        threeCount: 0,
        fourCount: 0,
        fiveCount: 0,
        sixPlusCount: 0,
      );

      expect(rule.totalSlots, 0);
      expect(rule.isValid, isTrue);
    });

    test('json round-trip preserves bucket values', () {
      const rule = CostCurveRule(
        enabled: true,
        cheapCount: 2,
        threeCount: 1,
        fourCount: 4,
        fiveCount: 2,
        sixPlusCount: 1,
      );

      final decoded = CostCurveRule.fromJsonString(rule.toJsonString());

      expect(decoded.enabled, isTrue);
      expect(decoded.bucketCounts, rule.bucketCounts);
    });
  });
}
