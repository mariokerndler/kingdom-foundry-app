import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';

void main() {
  test('SharePayload encode/decode round-trips exact kingdom data', () {
    const payload = SharePayload(
      kingdomCardIds: ['village', 'smithy'],
      landscapeCardIds: ['mission'],
      presetId: 'engine_builder',
      rulesSnapshot: SetupRules(requireVillage: true, landscapeEvents: 1),
      playerCount: 3,
      notes: ['Use one Ally.'],
    );

    final encoded = payload.encode();
    final decoded = SharePayload.tryDecode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.kingdomCardIds, ['village', 'smithy']);
    expect(decoded.landscapeCardIds, ['mission']);
    expect(decoded.presetId, 'engine_builder');
    expect(decoded.rulesSnapshot.requireVillage, isTrue);
    expect(decoded.playerCount, 3);
    expect(decoded.notes, ['Use one Ally.']);
  });
}
