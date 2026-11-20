import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingdom_foundry/models/setup_result.dart';
import 'package:kingdom_foundry/services/history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a damaged entry does not hide valid history or favorites', () async {
    final valid = SetupResult(
            kingdomCards: const [],
            archetypes: const [],
            setupNotes: const ['Recovered'],
            generatedAt: DateTime(2026))
        .toJson();
    final raw = jsonEncode([
      valid,
      {'generatedAt': 'invalid'},
      null,
      valid
    ]);
    SharedPreferences.setMockInitialValues({
      'kingdom_history': raw,
      'kingdom_favorites': raw,
    });
    final service = HistoryService(await SharedPreferences.getInstance());
    expect(service.loadHistory(), hasLength(2));
    expect(service.loadFavorites(), hasLength(1));
    expect(service.loadHistory().first.setupNotes, ['Recovered']);
    expect(service.hadUnreadableEntries, isTrue);
  });
}
