import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cost_curve_rule.dart';
import '../models/collection_profile.dart';
import '../models/expansion.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/setup_rules.dart';
import '../providers/config_provider.dart';

const _kSnapshot = 'cfg_snapshot_v1';
const _kExpansions = 'cfg_expansions';
const _kNoAttacks = 'cfg_no_attacks';
const _kNoDuration = 'cfg_no_duration';
const _kNoPotions = 'cfg_no_potions';
const _kNoDebt = 'cfg_no_debt';
const _kRequireBuy = 'cfg_require_buy';
const _kRequireTrash = 'cfg_require_trash';
const _kRequireVillage = 'cfg_require_village';
const _kMaxCost = 'cfg_max_cost';
const _kDisabledCards = 'cfg_disabled_cards';
const _kPlayerCount = 'cfg_player_count';
const _kIncludeLandscape = 'cfg_include_landscape';
const _kShowStrategyTips = 'cfg_show_strategy_tips';
const _kNoCursers = 'cfg_no_cursers';
const _kNoTravellers = 'cfg_no_travellers';
const _kRequireDraw = 'cfg_require_draw';
const _kRequireReactionIfAttacks = 'cfg_require_reaction_if_attacks';
const _kMaxAttacks = 'cfg_max_attacks';
const _kLandscapeEvents = 'cfg_landscape_events';
const _kLandscapeProjects = 'cfg_landscape_projects';
const _kLandscapeLandmarks = 'cfg_landscape_landmarks';
const _kLandscapeWays = 'cfg_landscape_ways';
const _kLandscapeAllies = 'cfg_landscape_allies';
const _kLandscapeTraits = 'cfg_landscape_traits';
const _kCostCurve = 'cfg_cost_curve';
const _kUseDarkMode = 'cfg_use_dark_mode';
const _kSelectedPresetId = 'cfg_selected_preset_id';
const _kSelectedLanguageCode = 'cfg_selected_language_code';

class ConfigPersistenceService {
  final SharedPreferences _prefs;
  Future<void> _pendingSave = Future.value();
  ConfigPersistenceService(this._prefs);

  T? _read<T>(String key) {
    final value = _prefs.get(key);
    return value is T ? value : null;
  }

  List<String>? _readNames(String key) {
    final raw = _read<String>(key);
    if (raw == null) return null;
    try {
      final values = jsonDecode(raw);
      return values is List ? values.whereType<String>().toList() : null;
    } catch (_) {
      return null;
    }
  }

  CostCurveRule _readCostCurve() {
    final raw = _read<String>(_kCostCurve);
    if (raw != null) {
      try {
        final curve = CostCurveRule.fromJsonString(raw);
        if (curve.bucketCounts.values
            .every((count) => count >= 0 && count <= 10)) {
          return curve;
        }
      } catch (_) {
        // Preserve other preferences when just the cost curve is damaged.
      }
    }
    return const CostCurveRule();
  }

  ConfigState load() {
    final raw = _read<String>(_kSnapshot);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        T? read<T>(String key) {
          final value = json[key];
          return value is T ? value : null;
        }

        final collections = <String, CollectionProfile>{};
        for (final entry in (read<Map>('collections') ?? const {}).entries) {
          if (entry.key is! String ||
              (entry.key as String).trim().isEmpty ||
              entry.value is! Map<String, dynamic>) {
            continue;
          }
          try {
            collections[entry.key as String] =
                CollectionProfile.fromJson(entry.value);
          } on TypeError {
            // One damaged profile should not affect other settings.
          }
        }
        final selectedName = read<String>('activeCollection') ?? '';
        final active = collections[selectedName];
        Set<Expansion> readExpansions(List names) => Expansion.values
            .where((expansion) => names.contains(expansion.name))
            .toSet();
        final quick = read<List>('quickSetupExpansions');
        final current = read<List>('expansions');

        return ConfigState(
          ownedExpansions: active?.selected ??
              (current == null
                  ? {Expansion.baseSecondEdition}
                  : readExpansions(current)),
          collections: collections,
          activeCollection: active == null ? '' : selectedName,
          quickSetupExpansions: quick == null ? null : readExpansions(quick),
          rules: SetupRules.fromJson(read<Map<String, dynamic>>('rules') ?? {}),
          disabledCardIds: (read<List>('bans') ?? [])
              .whereType<String>()
              .map(canonicalCardId)
              .toSet(),
          playerCount: (read<int>('players') ?? 2).clamp(2, 6),
          useDarkMode: read<bool>('darkMode') ?? false,
          selectedPresetId: GameVibePresets.byId(read<String>('preset')).id,
          selectedLanguageCode: read<String>('language') ?? 'en',
          preferFreshPiles: read<bool>('preferFreshPiles') ?? false,
        );
      } on FormatException {
        // Fall back to the legacy settings if the snapshot is damaged.
      } on TypeError {
        // The snapshot can be edited or corrupted outside the app.
      }
    }
    return _loadLegacy();
  }

  ConfigState _loadLegacy() {
    final names = _readNames(_kExpansions);
    Set<Expansion> ownedExpansions;
    if (names != null) {
      ownedExpansions = names
          .map((n) => Expansion.values.where((e) => e.name == n).firstOrNull)
          .whereType<Expansion>()
          .toSet();
    } else {
      ownedExpansions = {Expansion.baseSecondEdition};
    }

    final maxCostVal = _read<int>(_kMaxCost)?.clamp(2, 8);
    final maxAttacksVal = _read<int>(_kMaxAttacks)?.clamp(0, 5);
    final rules = SetupRules(
      noAttacks: _read<bool>(_kNoAttacks) ?? false,
      noDuration: _read<bool>(_kNoDuration) ?? false,
      noPotions: _read<bool>(_kNoPotions) ?? false,
      noDebt: _read<bool>(_kNoDebt) ?? false,
      noCursers: _read<bool>(_kNoCursers) ?? false,
      noTravellers: _read<bool>(_kNoTravellers) ?? false,
      requirePlusBuy: _read<bool>(_kRequireBuy) ?? false,
      requireTrashing: _read<bool>(_kRequireTrash) ?? false,
      requireVillage: _read<bool>(_kRequireVillage) ?? false,
      requireDraw: _read<bool>(_kRequireDraw) ?? false,
      requireReactionIfAttacks:
          _read<bool>(_kRequireReactionIfAttacks) ?? false,
      maxCost: maxCostVal,
      maxAttacks: maxAttacksVal,
      includeLandscape: _read<bool>(_kIncludeLandscape) ?? true,
      showStrategyTips: _read<bool>(_kShowStrategyTips) ?? true,
      landscapeEvents: (_read<int>(_kLandscapeEvents) ?? 2).clamp(0, 4),
      landscapeProjects: (_read<int>(_kLandscapeProjects) ?? 2).clamp(0, 4),
      landscapeLandmarks: (_read<int>(_kLandscapeLandmarks) ?? 1).clamp(0, 3),
      landscapeWays: (_read<int>(_kLandscapeWays) ?? 1).clamp(0, 4),
      landscapeAllies: (_read<int>(_kLandscapeAllies) ?? 1).clamp(0, 3),
      landscapeTraits: (_read<int>(_kLandscapeTraits) ?? 1).clamp(0, 4),
      costCurve: _readCostCurve(),
    );

    final disabledCardIds =
        (_readNames(_kDisabledCards) ?? []).map(canonicalCardId).toSet();

    return ConfigState(
      ownedExpansions: ownedExpansions,
      rules: rules,
      disabledCardIds: disabledCardIds,
      playerCount: (_read<int>(_kPlayerCount) ?? 2).clamp(2, 6),
      useDarkMode: _read<bool>(_kUseDarkMode) ?? false,
      selectedPresetId:
          _read<String>(_kSelectedPresetId) ?? GameVibePresets.noneId,
      selectedLanguageCode: _read<String>(_kSelectedLanguageCode) ?? 'en',
    );
  }

  Future<void> save(ConfigState state) {
    final operation = _pendingSave.then((_) async {
      final stored = await _prefs.setString(
          _kSnapshot,
          jsonEncode({
            'expansions': state.ownedExpansions
                .map((expansion) => expansion.name)
                .toList(),
            'rules': state.rules.toJson(),
            'bans': state.disabledCardIds.toList(),
            'players': state.playerCount,
            'darkMode': state.useDarkMode,
            'preset': state.selectedPresetId,
            'language': state.selectedLanguageCode,
            'preferFreshPiles': state.preferFreshPiles,
            if (state.collections.isNotEmpty)
              'collections': state.collections
                  .map((name, profile) => MapEntry(name, profile.toJson())),
            if (state.activeCollection.isNotEmpty)
              'activeCollection': state.activeCollection,
            if (state.quickSetupExpansions != null)
              'quickSetupExpansions': state.quickSetupExpansions!
                  .map((expansion) => expansion.name)
                  .toList(),
          }));
      if (!stored) throw StateError('Settings could not be saved.');
    });
    _pendingSave =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }
}
