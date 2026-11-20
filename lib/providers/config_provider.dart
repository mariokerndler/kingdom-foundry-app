import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collection_profile.dart';
import '../models/expansion.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/setup_rules.dart';
import '../services/config_persistence_service.dart';

final storageNoticeProvider =
    StateProvider<({String message, void Function()? retry})?>((ref) => null);

// ── State ──────────────────────────────────────────────────────────────────

class ConfigState {
  final Set<Expansion> ownedExpansions;
  final SetupRules rules;
  final Set<String> disabledCardIds;
  final int playerCount; // 2–6
  final bool useDarkMode;
  final String selectedPresetId;
  final String selectedLanguageCode;
  final bool preferFreshPiles;
  final Map<String, CollectionProfile> collections;
  final String activeCollection;
  final Set<Expansion>? quickSetupExpansions;

  const ConfigState({
    required this.ownedExpansions,
    required this.rules,
    required this.disabledCardIds,
    this.playerCount = 2,
    this.useDarkMode = false,
    this.selectedPresetId = GameVibePresets.noneId,
    this.selectedLanguageCode = 'en',
    this.preferFreshPiles = false,
    this.collections = const {},
    this.activeCollection = '',
    this.quickSetupExpansions,
  });

  bool isExpansionOwned(Expansion e) => ownedExpansions.contains(e);
  bool isCardDisabled(String id) => disabledCardIds.contains(id);
  CollectionProfile? get collection => collections[activeCollection];
  bool ownsCard(KingdomCard card) =>
      collection?.owns(card) ?? !card.firstEditionOnly;
  bool usesCard(KingdomCard card) =>
      isExpansionOwned(card.expansion) && ownsCard(card);

  Set<String> excludedCardIds(List<KingdomCard> cards) => {
        ...disabledCardIds,
        for (final card in cards)
          if (!ownsCard(card)) card.id,
      };

  ConfigState copyWith({
    Set<Expansion>? ownedExpansions,
    SetupRules? rules,
    Set<String>? disabledCardIds,
    int? playerCount,
    bool? useDarkMode,
    String? selectedPresetId,
    String? selectedLanguageCode,
    bool? preferFreshPiles,
    Map<String, CollectionProfile>? collections,
    String? activeCollection,
    Set<Expansion>? quickSetupExpansions,
  }) {
    return ConfigState(
      ownedExpansions: ownedExpansions ?? this.ownedExpansions,
      rules: rules ?? this.rules,
      disabledCardIds: disabledCardIds ?? this.disabledCardIds,
      playerCount: playerCount ?? this.playerCount,
      useDarkMode: useDarkMode ?? this.useDarkMode,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      preferFreshPiles: preferFreshPiles ?? this.preferFreshPiles,
      collections: collections ?? this.collections,
      activeCollection: activeCollection ?? this.activeCollection,
      quickSetupExpansions: quickSetupExpansions ?? this.quickSetupExpansions,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class ConfigNotifier extends StateNotifier<ConfigState> {
  final ConfigPersistenceService _persistence;
  final void Function(void Function() retry)? onSaveFailure;

  ConfigNotifier(this._persistence, {this.onSaveFailure})
      : super(_persistence.load());

  @override
  set state(ConfigState value) {
    super.state = value;
    _save(value);
  }

  Future<void> _save(ConfigState value) async {
    try {
      await _persistence.save(value);
    } catch (_) {
      if (mounted && identical(state, value)) {
        onSaveFailure?.call(() {
          if (mounted) _save(state);
        });
      }
    }
  }

  // ── Expansions ────────────────────────────────────────────────────────────

  void toggleExpansion(Expansion expansion) {
    final current = Set<Expansion>.from(state.ownedExpansions);
    if (current.contains(expansion)) {
      current.remove(expansion);
    } else {
      current.add(expansion);
    }
    _useExpansions(current);
  }

  void selectAllExpansions(Set<Expansion> available) =>
      _useExpansions(available);

  void clearExpansions() => _useExpansions({});

  void _useExpansions(Set<Expansion> expansions) {
    final profile = state.collection;
    if (profile == null) {
      state = state.copyWith(ownedExpansions: Set.of(expansions));
      return;
    }
    final updated = profile.withSelection(expansions);
    state = state.copyWith(
        ownedExpansions: updated.selected,
        collections: {...state.collections, state.activeCollection: updated});
  }

  void saveCollection(String name, CollectionProfile profile,
      {String? previousName}) {
    name = name.trim();
    if (name.isEmpty ||
        name.toLowerCase() == 'quick setup' ||
        state.collections.keys.any((key) =>
            key != previousName && key.toLowerCase() == name.toLowerCase())) {
      return;
    }
    final collections = {...state.collections};
    if (previousName != null && previousName != name) {
      collections.remove(previousName);
    }
    profile = profile.withSelection(profile.selected);
    collections[name] = profile;
    state = state.copyWith(
        collections: collections,
        activeCollection: name,
        ownedExpansions: profile.selected,
        quickSetupExpansions:
            state.collection == null ? state.ownedExpansions : null);
  }

  void selectCollection(String name) {
    if (name == state.activeCollection ||
        (name.isNotEmpty && !state.collections.containsKey(name))) {
      return;
    }
    state = state.copyWith(
        activeCollection: name,
        ownedExpansions: state.collections[name]?.selected ??
            state.quickSetupExpansions ??
            state.ownedExpansions,
        quickSetupExpansions:
            state.collection == null ? state.ownedExpansions : null);
  }

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

  void resetRules() => state = state.copyWith(
        rules: const SetupRules(),
        selectedPresetId: GameVibePresets.noneId,
      );

  void setSelectedPresetId(String presetId) {
    final preset = GameVibePresets.byId(presetId);
    if (preset.id == GameVibePresets.noneId) {
      state = state.copyWith(
        selectedPresetId: preset.id,
      );
      return;
    }
    state = state.copyWith(
      selectedPresetId: preset.id,
      rules: preset.rulesAppliedTo(state.rules),
    );
  }

  void restoreRules(SetupRules rules, String presetId) =>
      state = state.copyWith(rules: rules, selectedPresetId: presetId);

  // ── Player count ──────────────────────────────────────────────────────────

  void setPlayerCount(int count) =>
      state = state.copyWith(playerCount: count.clamp(2, 6));

  void useSetupSettings(
      {required SetupRules rules, required int playerCount, String? presetId}) {
    state = state.copyWith(
      rules: rules,
      playerCount: playerCount.clamp(2, 6),
      selectedPresetId: GameVibePresets.byId(presetId).id,
    );
  }

  void setUseDarkMode(bool v) => state = state.copyWith(useDarkMode: v);

  void setSelectedLanguageCode(String code) =>
      state = state.copyWith(selectedLanguageCode: code);

  void setPreferFreshPiles(bool value) =>
      state = state.copyWith(preferFreshPiles: value);

  // ── Card ban list ─────────────────────────────────────────────────────────

  void toggleCard(String cardId) {
    togglePileBan([cardId]);
  }

  void togglePileBan(Iterable<String> memberIds) {
    final current = Set<String>.from(state.disabledCardIds);
    if (memberIds.any(current.contains)) {
      current.removeAll(memberIds);
    } else {
      current.addAll(memberIds);
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
  (ref) => ConfigNotifier(ref.watch(configPersistenceProvider),
      onSaveFailure: (retry) {
    ref.read(storageNoticeProvider.notifier).state = (
      message: 'Settings changed for this session. They could not be saved.',
      retry: retry,
    );
  }),
);

// Convenience: player count extracted so widgets don't rebuild on other changes.
final playerCountProvider = Provider<int>(
  (ref) => ref.watch(configProvider).playerCount,
);
