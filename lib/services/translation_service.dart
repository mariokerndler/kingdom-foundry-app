import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/translation_pack.dart';

const _kImportedTranslationPacks = 'cfg_translation_packs';

class TranslationService {
  final SharedPreferences _prefs;

  const TranslationService(this._prefs);

  Future<List<TranslationPack>> loadAvailablePacks() async {
    final packs = <TranslationPack>[
      const TranslationPack(languageCode: 'en', label: 'English'),
      ...await _loadBundledPacks(),
      ..._loadImportedPacks(),
    ];

    final byCode = <String, TranslationPack>{};
    for (final pack in packs) {
      byCode[pack.languageCode] = pack;
    }
    return byCode.values.toList()..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<void> importPack(String rawJson) async {
    final candidate = TranslationPack.fromJsonString(rawJson);
    final existing = _loadImportedPacks();
    final byCode = {
      for (final pack in existing) pack.languageCode: pack,
      candidate.languageCode: candidate,
    };
    final jsonList = byCode.values.map((pack) => pack.toJson()).toList();
    await _prefs.setString(_kImportedTranslationPacks, jsonEncode(jsonList));
  }

  List<TranslationPack> _loadImportedPacks() {
    final raw = _prefs.getString(_kImportedTranslationPacks);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => TranslationPack.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<TranslationPack>> _loadBundledPacks() async {
    const assetPaths = [
      'assets/data/translations/de.json',
    ];
    final packs = <TranslationPack>[];
    for (final path in assetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        packs.add(TranslationPack.fromJsonString(raw));
      } catch (_) {
        // Best effort: missing bundled packs should not break the app.
      }
    }
    return packs;
  }
}
