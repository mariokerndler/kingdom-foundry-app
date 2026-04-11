import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cost_curve_rule.dart';
import '../models/expansion.dart';
import '../models/setup_rules.dart';
import '../providers/config_provider.dart';

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
    final maxAttacksVal = _prefs.getInt(_kMaxAttacks);
    final rawCostCurve = _prefs.getString(_kCostCurve);
    final rules = SetupRules(
      noAttacks: _prefs.getBool(_kNoAttacks) ?? false,
      noDuration: _prefs.getBool(_kNoDuration) ?? false,
      noPotions: _prefs.getBool(_kNoPotions) ?? false,
      noDebt: _prefs.getBool(_kNoDebt) ?? false,
      noCursers: _prefs.getBool(_kNoCursers) ?? false,
      noTravellers: _prefs.getBool(_kNoTravellers) ?? false,
      requirePlusBuy: _prefs.getBool(_kRequireBuy) ?? false,
      requireTrashing: _prefs.getBool(_kRequireTrash) ?? false,
      requireVillage: _prefs.getBool(_kRequireVillage) ?? false,
      requireDraw: _prefs.getBool(_kRequireDraw) ?? false,
      requireReactionIfAttacks:
          _prefs.getBool(_kRequireReactionIfAttacks) ?? false,
      maxCost: maxCostVal,
      maxAttacks: maxAttacksVal,
      includeLandscape: _prefs.getBool(_kIncludeLandscape) ?? true,
      landscapeEvents: _prefs.getInt(_kLandscapeEvents) ?? 2,
      landscapeProjects: _prefs.getInt(_kLandscapeProjects) ?? 2,
      landscapeLandmarks: _prefs.getInt(_kLandscapeLandmarks) ?? 1,
      landscapeWays: _prefs.getInt(_kLandscapeWays) ?? 1,
      landscapeAllies: _prefs.getInt(_kLandscapeAllies) ?? 1,
      landscapeTraits: _prefs.getInt(_kLandscapeTraits) ?? 1,
      costCurve: rawCostCurve == null
          ? const CostCurveRule()
          : CostCurveRule.fromJsonString(rawCostCurve),
    );

    final bannedJson = _prefs.getString(_kDisabledCards);
    final disabledCardIds = bannedJson != null
        ? (jsonDecode(bannedJson) as List).cast<String>().toSet()
        : <String>{};

    return ConfigState(
      ownedExpansions: ownedExpansions,
      rules: rules,
      disabledCardIds: disabledCardIds,
      playerCount: _prefs.getInt(_kPlayerCount) ?? 2,
    );
  }

  Future<void> save(ConfigState state) async {
    try {
      await Future.wait([
        _prefs.setString(
          _kExpansions,
          jsonEncode(state.ownedExpansions.map((e) => e.name).toList()),
        ),
        _prefs.setBool(_kNoAttacks, state.rules.noAttacks),
        _prefs.setBool(_kNoDuration, state.rules.noDuration),
        _prefs.setBool(_kNoPotions, state.rules.noPotions),
        _prefs.setBool(_kNoDebt, state.rules.noDebt),
        _prefs.setBool(_kNoCursers, state.rules.noCursers),
        _prefs.setBool(_kNoTravellers, state.rules.noTravellers),
        _prefs.setBool(_kRequireBuy, state.rules.requirePlusBuy),
        _prefs.setBool(_kRequireTrash, state.rules.requireTrashing),
        _prefs.setBool(_kRequireVillage, state.rules.requireVillage),
        _prefs.setBool(_kRequireDraw, state.rules.requireDraw),
        _prefs.setBool(
            _kRequireReactionIfAttacks, state.rules.requireReactionIfAttacks),
        _prefs.setString(
          _kDisabledCards,
          jsonEncode(state.disabledCardIds.toList()),
        ),
        _prefs.setInt(_kPlayerCount, state.playerCount),
        _prefs.setBool(_kIncludeLandscape, state.rules.includeLandscape),
        _prefs.setInt(_kLandscapeEvents, state.rules.landscapeEvents),
        _prefs.setInt(_kLandscapeProjects, state.rules.landscapeProjects),
        _prefs.setInt(_kLandscapeLandmarks, state.rules.landscapeLandmarks),
        _prefs.setInt(_kLandscapeWays, state.rules.landscapeWays),
        _prefs.setInt(_kLandscapeAllies, state.rules.landscapeAllies),
        _prefs.setInt(_kLandscapeTraits, state.rules.landscapeTraits),
        _prefs.setString(_kCostCurve, state.rules.costCurve.toJsonString()),
      ]);
      if (state.rules.maxCost != null) {
        await _prefs.setInt(_kMaxCost, state.rules.maxCost!);
      } else {
        await _prefs.remove(_kMaxCost);
      }
      if (state.rules.maxAttacks != null) {
        await _prefs.setInt(_kMaxAttacks, state.rules.maxAttacks!);
      } else {
        await _prefs.remove(_kMaxAttacks);
      }
    } catch (_) {
      // Best-effort — never crash the UI.
    }
  }
}
