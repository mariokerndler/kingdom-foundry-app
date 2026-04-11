import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expansion.dart';
import '../models/setup_rules.dart';
import '../services/config_persistence_service.dart';

// ── State ──────────────────────────────────────────────────────────────────

class ConfigState {
  final Set<Expansion> ownedExpansions;
  final SetupRules rules;
  final Set<String> disabledCardIds;
  final int playerCount; // 2–6
  final bool useDarkMode;

  const ConfigState({
    required this.ownedExpansions,
    required this.rules,
    required this.disabledCardIds,
    this.playerCount = 2,
    this.useDarkMode = false,
  });

  bool isExpansionOwned(Expansion e) => ownedExpansions.contains(e);
  bool isCardDisabled(String id) => disabledCardIds.contains(id);

  ConfigState copyWith({
    Set<Expansion>? ownedExpansions,
    SetupRules? rules,
    Set<String>? disabledCardIds,
    int? playerCount,
    bool? useDarkMode,
  }) {
    return ConfigState(
      ownedExpansions: ownedExpansions ?? this.ownedExpansions,
      rules: rules ?? this.rules,
      disabledCardIds: disabledCardIds ?? this.disabledCardIds,
      playerCount: playerCount ?? this.playerCount,
      useDarkMode: useDarkMode ?? this.useDarkMode,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class ConfigNotifier extends StateNotifier<ConfigState> {
  final ConfigPersistenceService _persistence;

  ConfigNotifier(this._persistence) : super(_persistence.load());

  @override
  set state(ConfigState value) {
    super.state = value;
    _persistence.save(value);
  }

  // ── Expansions ────────────────────────────────────────────────────────────

  void toggleExpansion(Expansion expansion) {
    final current = Set<Expansion>.from(state.ownedExpansions);
    if (current.contains(expansion)) {
      current.remove(expansion);
    } else {
      current.add(expansion);
    }
    state = state.copyWith(ownedExpansions: current);
  }

  void selectAllExpansions(Set<Expansion> available) =>
      state = state.copyWith(ownedExpansions: Set.from(available));

  void clearExpansions() => state = state.copyWith(ownedExpansions: {});

  // ── Rules ─────────────────────────────────────────────────────────────────

  void setNoAttacks(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noAttacks: v));

  void setNoDuration(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noDuration: v));

  void setNoPotions(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noPotions: v));

  void setNoDebt(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noDebt: v));

  void setRequirePlusBuy(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(requirePlusBuy: v));

  void setRequireTrashing(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(requireTrashing: v));

  void setRequireVillage(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(requireVillage: v));

  void setMaxCost(int? cost) {
    state = state.copyWith(
      rules: state.rules.copyWith(maxCost: cost, clearMaxCost: cost == null),
    );
  }

  void setNoCursers(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noCursers: v));

  void setNoTravellers(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(noTravellers: v));

  void setRequireDraw(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(requireDraw: v));

  void setRequireReactionIfAttacks(bool v) => state =
      state.copyWith(rules: state.rules.copyWith(requireReactionIfAttacks: v));

  void setMaxAttacks(int? count) {
    state = state.copyWith(
      rules: state.rules
          .copyWith(maxAttacks: count, clearMaxAttacks: count == null),
    );
  }

  void setIncludeLandscape(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(includeLandscape: v));

  void setShowStrategyTips(bool v) =>
      state = state.copyWith(rules: state.rules.copyWith(showStrategyTips: v));

  void setLandscapeEvents(int v) =>
      state = state.copyWith(rules: state.rules.copyWith(landscapeEvents: v));

  void setLandscapeProjects(int v) =>
      state = state.copyWith(rules: state.rules.copyWith(landscapeProjects: v));

  void setLandscapeLandmarks(int v) => state =
      state.copyWith(rules: state.rules.copyWith(landscapeLandmarks: v));

  void setLandscapeWays(int v) =>
      state = state.copyWith(rules: state.rules.copyWith(landscapeWays: v));

  void setLandscapeAllies(int v) =>
      state = state.copyWith(rules: state.rules.copyWith(landscapeAllies: v));

  void setLandscapeTraits(int v) =>
      state = state.copyWith(rules: state.rules.copyWith(landscapeTraits: v));

  void setCostCurveEnabled(bool v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        enabled: v,
      )));

  void setCostCurveCheapCount(int v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        cheapCount: v,
      )));

  void setCostCurveThreeCount(int v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        threeCount: v,
      )));

  void setCostCurveFourCount(int v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        fourCount: v,
      )));

  void setCostCurveFiveCount(int v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        fiveCount: v,
      )));

  void setCostCurveSixPlusCount(int v) => state = state.copyWith(
          rules: state.rules.copyWith(
              costCurve: state.rules.costCurve.copyWith(
        sixPlusCount: v,
      )));

  void resetCostCurve() => state = state.copyWith(
        rules: state.rules.copyWith(
          costCurve: state.rules.costCurve.copyWith(
            cheapCount: 1,
            threeCount: 2,
            fourCount: 3,
            fiveCount: 3,
            sixPlusCount: 1,
          ),
        ),
      );

  void resetRules() => state = state.copyWith(rules: const SetupRules());

  // ── Player count ──────────────────────────────────────────────────────────

  void setPlayerCount(int count) =>
      state = state.copyWith(playerCount: count.clamp(2, 6));

  void setUseDarkMode(bool v) => state = state.copyWith(useDarkMode: v);

  // ── Card ban list ─────────────────────────────────────────────────────────

  void toggleCard(String cardId) {
    final current = Set<String>.from(state.disabledCardIds);
    if (current.contains(cardId)) {
      current.remove(cardId);
    } else {
      current.add(cardId);
    }
    state = state.copyWith(disabledCardIds: current);
  }

  void enableAllCards() => state = state.copyWith(disabledCardIds: {});
}

// ── Providers ─────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider not initialized'),
);

final configPersistenceProvider = Provider<ConfigPersistenceService>(
  (ref) => ConfigPersistenceService(ref.watch(sharedPreferencesProvider)),
);

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>(
  (ref) => ConfigNotifier(ref.watch(configPersistenceProvider)),
);

// Convenience: player count extracted so widgets don't rebuild on other changes.
final playerCountProvider = Provider<int>(
  (ref) => ref.watch(configProvider).playerCount,
);
