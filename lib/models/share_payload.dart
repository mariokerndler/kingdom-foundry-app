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
        'version': version,
        'kingdomCardIds': kingdomCardIds,
        'landscapeCardIds': landscapeCardIds,
        'presetId': presetId,
        'rulesSnapshot': rulesSnapshot.toJson(),
        'playerCount': playerCount,
        'notes': notes,
      };

  factory SharePayload.fromJson(Map<String, dynamic> json) => SharePayload(
        version: json['version'] as int? ?? 1,
        kingdomCardIds:
            (json['kingdomCardIds'] as List? ?? const []).cast<String>(),
        landscapeCardIds:
            (json['landscapeCardIds'] as List? ?? const []).cast<String>(),
        presetId: json['presetId'] as String?,
        rulesSnapshot: json['rulesSnapshot'] is Map<String, dynamic>
            ? SetupRules.fromJson(json['rulesSnapshot'] as Map<String, dynamic>)
            : const SetupRules(),
        playerCount: json['playerCount'] as int? ?? 2,
        notes: (json['notes'] as List? ?? const []).cast<String>(),
      );

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
