import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/services/card_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('simultaneous catalogue requests share a load; failures can retry',
      () async {
    const path = 'assets/data/cards.json';
    rootBundle.evict(path);
    var reads = 0;
    var valid = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      reads++;
      return ByteData.sublistView(
          Uint8List.fromList(utf8.encode(valid ? '[]' : '{broken')));
    });
    addTearDown(() {
      rootBundle.evict(path);
      messenger.setMockMessageHandler('flutter/assets', null);
    });
    final service = CardDataService();
    final first = service.loadAll();
    expect(identical(first, service.loadAll()), isTrue);
    await expectLater(first, throwsFormatException);
    expect(reads, 1);
    valid = true;
    rootBundle.evict(path);
    expect(await service.loadAll(), isEmpty);
    expect(reads, 2);
    final cached = service.loadAll();
    expect(identical(cached, service.loadAll()), isTrue);
    service.invalidate();
    expect(identical(cached, service.loadAll()), isFalse);
    await service.loadAll();
  });
}
