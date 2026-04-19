import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';

void main() {
  test('KF1 encode/decode round-trips legacy payload fields', () {
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
    expect(decoded.notes, isEmpty);
  });

  test('KF2 round-trips a kingdom-only board', () {
    final allCards = _sampleBaseKingdomCards();
    final payload = SharePayload(
      kingdomCardIds: allCards.map((card) => card.id).toList(),
    );

    final encoded = payload.encodeCompact(allCards);
    final decoded = SharePayload.tryDecodeCompact(encoded, allCards);

    expect(encoded, startsWith(SharePayload.compactPrefix));
    expect(decoded, isNotNull);
    expect(decoded!.version, 2);
    expect(decoded.kingdomCardIds, payload.kingdomCardIds);
    expect(decoded.landscapeCardIds, isEmpty);
    expect(encoded.length, lessThan(24));
  });

  test('KF2 round-trips boards with 1, 2, and several landscapes', () {
    final allCards = [
      ..._sampleBaseKingdomCards(),
      _event('advance'),
      _event('alms'),
      _event('ball'),
      _event('banish'),
      _event('bonfire'),
    ];

    for (final landscapeIds in [
      ['advance'],
      ['advance', 'alms'],
      ['advance', 'alms', 'ball', 'banish', 'bonfire'],
    ]) {
      final payload = SharePayload(
        kingdomCardIds: _sampleBaseKingdomCards().map((card) => card.id).toList(),
        landscapeCardIds: landscapeIds,
      );

      final encoded = payload.encodeCompact(allCards);
      final decoded = SharePayload.tryDecodeCompact(encoded, allCards);

      expect(decoded, isNotNull);
      expect(decoded!.landscapeCardIds, landscapeIds);
    }
  });

  test('KF2 encodes split piles as one slot and reconstructs all members', () {
    final allCards = [
      _kingdom('artisan', cost: 1),
      _kingdom('bandit', cost: 2),
      _kingdom('cellar', cost: 3),
      _kingdom('chapel', cost: 4),
      _kingdom('councilRoom', cost: 5, name: 'Council Room'),
      _kingdom('festival', cost: 6),
      _kingdom('laboratory', cost: 7),
      _kingdom('moat', cost: 8),
      _kingdom('village', cost: 9),
      _kingdom(
        'avanto',
        cost: 10,
        splitPileId: 'promos_sauna_avanto',
        name: 'Avanto',
      ),
      _kingdom(
        'sauna',
        cost: 11,
        splitPileId: 'promos_sauna_avanto',
        name: 'Sauna',
      ),
    ];
    final payload = SharePayload(
      kingdomCardIds: [
        'artisan',
        'bandit',
        'cellar',
        'chapel',
        'councilRoom',
        'festival',
        'laboratory',
        'moat',
        'village',
        'avanto',
        'sauna',
      ],
    );

    final encoded = payload.encodeCompact(allCards);
    final decoded = SharePayload.tryDecodeCompact(encoded, allCards);

    expect(decoded, isNotNull);
    expect(decoded!.kingdomCardIds, containsAll(['avanto', 'sauna']));
    expect(decoded.kingdomCardIds.length, 11);
  });

  test('KF2 rejects typo and truncation checksum failures', () {
    final allCards = _sampleBaseKingdomCards();
    final payload = SharePayload(
      kingdomCardIds: allCards.map((card) => card.id).toList(),
    );

    final encoded = payload.encodeCompact(allCards);
    final typo = '${encoded.substring(0, encoded.length - 1)}'
        '${encoded.endsWith('2') ? '3' : '2'}';
    final truncated = encoded.substring(0, encoded.length - 1);

    expect(SharePayload.tryDecodeCompact(typo, allCards), isNull);
    expect(SharePayload.tryDecodeCompact(truncated, allCards), isNull);
  });

  test('KF2 decode order is deterministic regardless of card list order', () {
    final cards = [
      _kingdom('artisan', cost: 5, name: 'Artisan'),
      _kingdom('bandit', cost: 2, name: 'Bandit'),
      _kingdom('cellar', cost: 1, name: 'Cellar'),
      _kingdom('chapel', cost: 3, name: 'Chapel'),
      _kingdom('festival', cost: 4, name: 'Festival'),
      _kingdom('laboratory', cost: 6, name: 'Laboratory'),
      _kingdom('moat', cost: 7, name: 'Moat'),
      _kingdom('village', cost: 8, name: 'Village'),
      _kingdom('smithy', cost: 9, name: 'Smithy'),
      _kingdom(
        'sauna',
        cost: 11,
        splitPileId: 'promos_sauna_avanto',
        name: 'Sauna',
      ),
      _kingdom(
        'avanto',
        cost: 10,
        splitPileId: 'promos_sauna_avanto',
        name: 'Avanto',
      ),
      _project('academy'),
      _event('advance'),
    ];
    final payload = SharePayload(
      kingdomCardIds: [
        'artisan',
        'bandit',
        'cellar',
        'chapel',
        'festival',
        'laboratory',
        'moat',
        'village',
        'smithy',
        'sauna',
        'avanto',
      ],
      landscapeCardIds: ['academy', 'advance'],
    );

    final encoded = payload.encodeCompact(cards);
    final decodedA = SharePayload.tryDecodeCompact(encoded, cards);
    final decodedB = SharePayload.tryDecodeCompact(
      encoded,
      cards.reversed.toList(),
    );

    expect(decodedA, isNotNull);
    expect(decodedB, isNotNull);
    expect(decodedA!.kingdomCardIds, decodedB!.kingdomCardIds);
    expect(decodedA.landscapeCardIds, decodedB.landscapeCardIds);
  });

  test('share code helpers detect KF1 and KF2 and keep KF1 import support', () {
    final legacy = const SharePayload(
      kingdomCardIds: ['village', 'smithy'],
    ).encode();
    final cards = _sampleBaseKingdomCards();
    final compact = SharePayload(
      kingdomCardIds: cards.map((card) => card.id).toList(),
    ).encodeCompact(cards);

    expect(SharePayload.looksLikeShareCode(legacy), isTrue);
    expect(SharePayload.looksLikeShareCode(compact), isTrue);
    expect(SharePayload.tryDecodeAny(legacy, cards), isNotNull);
    expect(SharePayload.tryDecodeAny(compact, cards), isNotNull);
  });

  test('KF2 keeps typical landscape boards short', () {
    final allCards = [
      ..._sampleBaseKingdomCards(),
      _event('advance'),
      _event('alms'),
    ];
    final payload = SharePayload(
      kingdomCardIds: _sampleBaseKingdomCards().map((card) => card.id).toList(),
      landscapeCardIds: const ['advance', 'alms'],
    );

    final encoded = payload.encodeCompact(allCards);

    expect(encoded.length, lessThan(28));
  });
}

List<KingdomCard> _sampleBaseKingdomCards() => [
      _kingdom('artisan', cost: 1, name: 'Artisan'),
      _kingdom('bandit', cost: 2, name: 'Bandit'),
      _kingdom('cellar', cost: 3, name: 'Cellar'),
      _kingdom('chapel', cost: 4, name: 'Chapel'),
      _kingdom('councilRoom', cost: 5, name: 'Council Room'),
      _kingdom('festival', cost: 6, name: 'Festival'),
      _kingdom('gardens', cost: 7, name: 'Gardens'),
      _kingdom('laboratory', cost: 8, name: 'Laboratory'),
      _kingdom('moat', cost: 9, name: 'Moat'),
      _kingdom('village', cost: 10, name: 'Village'),
    ];

KingdomCard _kingdom(
  String id, {
  required int cost,
  String? name,
  String? splitPileId,
}) {
  return KingdomCard(
    id: id,
    name: name ?? id,
    expansion: Expansion.base,
    types: const [CardType.action],
    tags: const [],
    cost: cost,
    text: '',
    splitPileId: splitPileId,
  );
}

KingdomCard _event(String id) {
  return KingdomCard(
    id: id,
    name: id,
    expansion: Expansion.adventures,
    types: const [CardType.event],
    tags: const [],
    cost: 0,
    text: '',
  );
}

KingdomCard _project(String id) {
  return KingdomCard(
    id: id,
    name: id,
    expansion: Expansion.renaissance,
    types: const [CardType.project],
    tags: const [],
    cost: 0,
    text: '',
  );
}
