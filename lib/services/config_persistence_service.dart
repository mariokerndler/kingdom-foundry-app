import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/expansion.dart';
import '../models/setup_rules.dart';
import '../providers/config_provider.dart';

const _kExpansions     = 'cfg_expansions';
const _kNoAttacks      = 'cfg_no_attacks';
const _kNoDuration     = 'cfg_no_duration';
const _kNoPotions      = 'cfg_no_potions';
const _kNoDebt         = 'cfg_no_debt';
const _kRequireBuy     = 'cfg_require_buy';
const _kRequireTrash   = 'cfg_require_trash';
const _kRequireVillage = 'cfg_require_village';
const _kMaxCost        = 'cfg_max_cost';
const _kDisabledCards  = 'cfg_disabled_cards';
const _kPlayerCount      = 'cfg_player_count';
const _kIncludeLandscape = 'cfg_include_landscape';

class ConfigPersistenceService {
  final SharedPreferences _prefs;
  ConfigPersistenceService(this._prefs);

  ConfigState load() {
    final expansionJson = _prefs.getString(_kExpansions);
    Set<Expansion> ownedExpansions;
    if (expansionJson != null) {
      final names = (jsonDecode(expansionJson) as List).cast<String>();
      ownedExpansions = names
          .map((n) => Expansion.values.where((e) => e.name == n).firstOrNull)
          .whereType<Expansion>()
          .toSet();
    } else {
      ownedExpansions = {Expansion.baseSecondEdition};
    }

    final maxCostVal = _prefs.getInt(_kMaxCost);
    final rules = SetupRules(
      noAttacks:        _prefs.getBool(_kNoAttacks)        ?? false,
      noDuration:       _prefs.getBool(_kNoDuration)       ?? false,
      noPotions:        _prefs.getBool(_kNoPotions)        ?? false,
      noDebt:           _prefs.getBool(_kNoDebt)           ?? false,
      requirePlusBuy:   _prefs.getBool(_kRequireBuy)       ?? false,
      requireTrashing:  _prefs.getBool(_kRequireTrash)     ?? false,
      requireVillage:   _prefs.getBool(_kRequireVillage)   ?? false,
      maxCost:          maxCostVal,
      includeLandscape: _prefs.getBool(_kIncludeLandscape) ?? true,
    );

    final bannedJson = _prefs.getString(_kDisabledCards);
    final disabledCardIds = bannedJson != null
        ? (jsonDecode(bannedJson) as List).cast<String>().toSet()
        : <String>{};

    return ConfigState(
      ownedExpansions: ownedExpansions,
      rules:           rules,
      disabledCardIds: disabledCardIds,
      playerCount:     _prefs.getInt(_kPlayerCount) ?? 2,
    );
  }

  Future<void> save(ConfigState state) async {
    try {
      await Future.wait([
        _prefs.setString(
          _kExpansions,
          jsonEncode(state.ownedExpansions.map((e) => e.name).toList()),
        ),
        _prefs.setBool(_kNoAttacks,      state.rules.noAttacks),
        _prefs.setBool(_kNoDuration,     state.rules.noDuration),
        _prefs.setBool(_kNoPotions,      state.rules.noPotions),
        _prefs.setBool(_kNoDebt,         state.rules.noDebt),
        _prefs.setBool(_kRequireBuy,     state.rules.requirePlusBuy),
        _prefs.setBool(_kRequireTrash,   state.rules.requireTrashing),
        _prefs.setBool(_kRequireVillage, state.rules.requireVillage),
        _prefs.setString(
          _kDisabledCards,
          jsonEncode(state.disabledCardIds.toList()),
        ),
        _prefs.setInt(_kPlayerCount, state.playerCount),
        _prefs.setBool(_kIncludeLandscape, state.rules.includeLandscape),
      ]);
      if (state.rules.maxCost != null) {
        await _prefs.setInt(_kMaxCost, state.rules.maxCost!);
      } else {
        await _prefs.remove(_kMaxCost);
      }
    } catch (_) {
      // Best-effort — never crash the UI.
    }
  }
}
