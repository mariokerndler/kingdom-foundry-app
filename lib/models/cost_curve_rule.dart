import 'dart:convert';

/// Optional best-effort preference for the 10 kingdom slots' coin-cost spread.
class CostCurveRule {
  static const int targetSlotCount = 10;

  final bool enabled;
  final int cheapCount; // <= 2
  final int threeCount;
  final int fourCount;
  final int fiveCount;
  final int sixPlusCount; // >= 6

  const CostCurveRule({
    this.enabled = false,
    this.cheapCount = 1,
    this.threeCount = 2,
    this.fourCount = 3,
    this.fiveCount = 3,
    this.sixPlusCount = 1,
  });

  int get totalSlots =>
      cheapCount + threeCount + fourCount + fiveCount + sixPlusCount;

  bool get isValid => !enabled || totalSlots == targetSlotCount;

  int get exactMatchSlotCount {
    final buckets = bucketCounts;
    return [
      if (buckets.containsKey('<=2')) _min(cheapCount, buckets['<=2']!),
      if (buckets.containsKey('3')) _min(threeCount, buckets['3']!),
      if (buckets.containsKey('4')) _min(fourCount, buckets['4']!),
      if (buckets.containsKey('5')) _min(fiveCount, buckets['5']!),
      if (buckets.containsKey('6+')) _min(sixPlusCount, buckets['6+']!),
    ].fold(0, (sum, value) => sum + value);
  }

  Map<String, int> get bucketCounts => {
        '<=2': cheapCount,
        '3': threeCount,
        '4': fourCount,
        '5': fiveCount,
        '6+': sixPlusCount,
      };

  String get targetDescription =>
      'Cost curve: <=2:$cheapCount, 3:$threeCount, 4:$fourCount, '
      '5:$fiveCount, 6+:$sixPlusCount';

  CostCurveRule copyWith({
    bool? enabled,
    int? cheapCount,
    int? threeCount,
    int? fourCount,
    int? fiveCount,
    int? sixPlusCount,
  }) {
    return CostCurveRule(
      enabled: enabled ?? this.enabled,
      cheapCount: cheapCount ?? this.cheapCount,
      threeCount: threeCount ?? this.threeCount,
      fourCount: fourCount ?? this.fourCount,
      fiveCount: fiveCount ?? this.fiveCount,
      sixPlusCount: sixPlusCount ?? this.sixPlusCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'cheapCount': cheapCount,
        'threeCount': threeCount,
        'fourCount': fourCount,
        'fiveCount': fiveCount,
        'sixPlusCount': sixPlusCount,
      };

  String toJsonString() => jsonEncode(toJson());

  factory CostCurveRule.fromJson(Map<String, dynamic> json) {
    return CostCurveRule(
      enabled: json['enabled'] as bool? ?? false,
      cheapCount: json['cheapCount'] as int? ?? 1,
      threeCount: json['threeCount'] as int? ?? 2,
      fourCount: json['fourCount'] as int? ?? 3,
      fiveCount: json['fiveCount'] as int? ?? 3,
      sixPlusCount: json['sixPlusCount'] as int? ?? 1,
    );
  }

  factory CostCurveRule.fromJsonString(String raw) {
    return CostCurveRule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static String describeBucketCounts(Map<String, int> counts) {
    return '<=2:${counts['<=2'] ?? 0}, 3:${counts['3'] ?? 0}, '
        '4:${counts['4'] ?? 0}, 5:${counts['5'] ?? 0}, 6+:${counts['6+'] ?? 0}';
  }

  static int _min(int a, int b) => a < b ? a : b;
}
