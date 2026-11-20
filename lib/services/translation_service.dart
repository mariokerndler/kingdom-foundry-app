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

  static TranslationPack validatePack(String rawJson, Set<String> cardIds) {
    final raw = jsonDecode(rawJson);
    if (raw is! Map<String, dynamic> ||
        raw['languageCode'] is! String ||
        raw['label'] is! String ||
        raw['cards'] is! Map<String, dynamic>) {
      throw const FormatException(
          'Expected a language code, label, and card map.');
    }
    final candidate = TranslationPack.fromJson(raw);
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$')
            .hasMatch(candidate.languageCode) ||
        candidate.languageCode == 'en' ||
        candidate.label.trim().isEmpty ||
        candidate.version != 1 ||
        candidate.cards.isEmpty) {
      throw const FormatException(
          'Use a non-English language code, a label, version 1, and at least one card.');
    }
    for (final entry in candidate.cards.entries) {
      if (!cardIds.contains(entry.key)) {
        throw FormatException('Unknown card ID: ${entry.key}.');
      }
      if (entry.value.name.trim().isEmpty && entry.value.text.trim().isEmpty) {
        throw FormatException(
            '${entry.key} needs a translated name or rules text.');
      }
    }
    return candidate;
  }

  Future<void> importPack(String rawJson, Set<String> cardIds) async {
    final candidate = validatePack(rawJson, cardIds);
    final existing = _loadImportedPacks();
    final byCode = {
      for (final pack in existing) pack.languageCode: pack,
      candidate.languageCode: candidate,
    };
    final jsonList = byCode.values.map((pack) => pack.toJson()).toList();
    if (!await _prefs.setString(
        _kImportedTranslationPacks, jsonEncode(jsonList))) {
      throw StateError('Could not save the translation pack.');
    }
  }

  List<TranslationPack> _loadImportedPacks() {
    try {
      final raw = _prefs.getString(_kImportedTranslationPacks);
      if (raw == null) return const [];
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
