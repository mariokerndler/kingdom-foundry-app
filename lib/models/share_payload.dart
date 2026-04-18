import 'dart:convert';

import 'setup_rules.dart';

class SharePayload {
  static const prefix = 'KF1:';

  final int version;
  final List<String> kingdomCardIds;
  final List<String> landscapeCardIds;
  final String? presetId;
  final SetupRules rulesSnapshot;
  final int playerCount;
  final List<String> notes;

  const SharePayload({
    this.version = 1,
    required this.kingdomCardIds,
    this.landscapeCardIds = const [],
    this.presetId,
    this.rulesSnapshot = const SetupRules(),
    this.playerCount = 2,
    this.notes = const [],
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'k': kingdomCardIds,
        if (landscapeCardIds.isNotEmpty) 'l': landscapeCardIds,
        if (presetId != null) 'p': presetId,
        if (_shouldIncludeRules) 'r': rulesSnapshot.toJson(),
        if (playerCount != 2) 'c': playerCount,
      };

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
        version: (json['version'] ?? json['v']) as int? ?? 1,
        kingdomCardIds:
            ((json['kingdomCardIds'] ?? json['k']) as List? ?? const [])
                .cast<String>(),
        landscapeCardIds:
            ((json['landscapeCardIds'] ?? json['l']) as List? ?? const [])
                .cast<String>(),
        presetId: (json['presetId'] ?? json['p']) as String?,
        rulesSnapshot: (json['rulesSnapshot'] ?? json['r'])
                is Map<String, dynamic>
            ? SetupRules.fromJson(
                (json['rulesSnapshot'] ?? json['r']) as Map<String, dynamic>,
              )
            : const SetupRules(),
        playerCount: (json['playerCount'] ?? json['c']) as int? ?? 2,
        notes: (json['notes'] as List? ?? const []).cast<String>(),
      );

  bool get _shouldIncludeRules => rulesSnapshot.hasActiveRules;

  String encode() {
    final raw = utf8.encode(jsonEncode(toJson()));
    return '$prefix${base64Url.encode(raw)}';
  }

  static SharePayload? tryDecode(String raw) {
    final value = raw.trim();
    if (!value.startsWith(prefix)) return null;
    try {
      final encoded = value.substring(prefix.length);
      final decoded = utf8.decode(base64Url.decode(encoded));
      return SharePayload.fromJson(jsonDecode(decoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
