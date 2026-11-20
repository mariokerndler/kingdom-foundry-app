import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/heuristic_engine.dart';
import '../controllers/setup_engine.dart';
import '../controllers/setup_exception.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/share_codebook.dart';
import '../models/share_payload.dart';
import '../models/setup_result.dart';
import '../models/setup_rules.dart';
import '../models/teaching_kingdom.dart';
import '../models/translation_pack.dart';
import '../services/history_service.dart';
import 'card_data_providers.dart';
import 'config_provider.dart';
import 'history_provider.dart';
import 'translation_provider.dart';

// ── Last generated result (null until first run) ──────────────────────────

final setupResultProvider = StateProvider<SetupResult?>((ref) => null);

final _lastRerollProvider =
    StateProvider<({SetupResult before, SetupResult after})?>((ref) => null);
final canUndoRerollProvider = Provider<bool>((ref) {
  final last = ref.watch(_lastRerollProvider);
  return last != null &&
      ref.watch(setupResultProvider)?.generatedAt == last.after.generatedAt;
});

void undoLastReroll(ProviderContainer ref) {
  if (!ref.read(canUndoRerollProvider) ||
      ref.read(generationStatusProvider) == GenerationStatus.loading) {
    return;
  }
  ref.read(setupResultProvider.notifier).state =
      ref.read(_lastRerollProvider)!.before;
  ref.read(_lastRerollProvider.notifier).state = null;
}

// ── Generation status ─────────────────────────────────────────────────────

enum GenerationStatus { idle, loading, error }

final _generationStatusProvider =
    StateProvider<GenerationStatus>((ref) => GenerationStatus.idle);

final _generationErrorProvider = StateProvider<String?>((ref) => null);
final _generationReasonProvider =
    StateProvider<SetupFailureReason?>((ref) => null);

// Convenience read-only providers for the UI
final generationStatusProvider =
    Provider<GenerationStatus>((ref) => ref.watch(_generationStatusProvider));

final generationErrorProvider =
    Provider<String?>((ref) => ref.watch(_generationErrorProvider));

/// The typed [SetupFailureReason] for the last error, if any.
final generationFailureReasonProvider = Provider<SetupFailureReason?>(
    (ref) => ref.watch(_generationReasonProvider));

void clearGenerationFeedback(WidgetRef ref) {
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
}

void setGenerationFeedback(
  WidgetRef ref, {
  required String message,
  SetupFailureReason? reason,
}) {
  ref.read(_generationErrorProvider.notifier).state = message;
  ref.read(_generationReasonProvider.notifier).state = reason;
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
}

// ── Shared engine singletons ──────────────────────────────────────────────

/// Singletons reused across calls — both are stateless.
final _setupEngine = SetupEngine();
final _heuristicEngine = HeuristicEngine();

// ── Generate action ───────────────────────────────────────────────────────

/// Call this from a button handler to run the full pipeline.
///
/// Returns `true` on success, `false` on [SetupException].
/// Updates [setupResultProvider] and [generationStatusProvider] reactively.
Future<bool> generateKingdom(
  WidgetRef ref, {
  TeachingKingdom? teaching,
  GameVibePreset? presetOverride,
}) async {
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;

  try {
    final allRaw = await ref.read(allCardsProvider.future);
    final config = ref.read(configProvider);

    final rules = teaching != null
        ? SetupRules(
            includeLandscape: false,
            showStrategyTips: config.rules.showStrategyTips)
        : presetOverride?.rulesAppliedTo(config.rules) ?? config.rules;
    final SetupResult result;
    if (teaching != null) {
      final kingdom = resolveTeachingKingdom(teaching, allRaw, config);
      if (kingdom == null) {
        throw const SetupException(
            'This teaching kingdom needs cards outside the current selection. Review your expansions and bans.',
            SetupFailureReason.poolTooSmall);
      }
      result = SetupResult(
        kingdomCards: _sortImportedKingdomCards(kingdom),
        archetypes: const [],
        setupNotes: _setupEngine.generateSetupNotes(kingdom, const []),
        selectionRationale: ['${teaching.name}: ${teaching.lesson}'],
        generatedAt: DateTime.now(),
      );
    } else {
      result = _setupEngine.generate(
        allCards: allRaw,
        excludedCardIds: config.excludedCardIds(allRaw),
        ownedExpansions: config.ownedExpansions,
        rules: rules,
        preset: presetOverride ?? GameVibePresets.byId(config.selectedPresetId),
        recentSlots: config.preferFreshPiles
            ? await _recentSlots(ref.read(historyServiceProvider))
            : const {},
      );
    }

    final enriched = _heuristicEngine.enrich(result).copyWith(
          rulesSnapshot: rules,
          playerCount: config.playerCount,
        );

    ref.read(setupResultProvider.notifier).state = enriched;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
    ref.read(historyProvider.notifier).push(enriched); // fire-and-forget
    return true;
  } on SetupException catch (e) {
    ref.read(_generationErrorProvider.notifier).state = e.message;
    ref.read(_generationReasonProvider.notifier).state = e.reason;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  } catch (e) {
    ref.read(_generationErrorProvider.notifier).state =
        'Unexpected error: ${e.toString()}';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }
}

List<KingdomCard>? resolveTeachingKingdom(
    TeachingKingdom teaching, List<KingdomCard> catalogue, ConfigState config) {
  final byId = {for (final card in catalogue) card.id: card};
  final selected = <KingdomCard>[];
  for (final id in teaching.cardIds) {
    final card = byId[id];
    if (card == null ||
        !card.isKingdomCard ||
        !config.usesCard(card) ||
        config.isCardDisabled(id)) {
      return null;
    }
    selected.add(card);
  }
  validateImportedKingdom(catalogue, selected);
  return selected;
}

Future<Set<String>> _recentSlots(HistoryService history) async {
  try {
    return (await history.loadCommittedHistory())
        .take(3)
        .expand((result) => result.kingdomSlotIds)
        .toSet();
  } catch (_) {
    return const {};
  }
}

// ── Import action ─────────────────────────────────────────────────────────

/// Parses [rawText] (produced by the "Copy kingdom" action) and loads the
/// matched cards into [setupResultProvider], then runs heuristic analysis.
///
/// Returns `true` on success. On failure, sets [generationErrorProvider] and
/// returns `false`.
Future<bool> importKingdom(WidgetRef ref, String rawText) async {
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;

  try {
    final allCards = await ref.read(allCardsProvider.future);
    final sharePayload = SharePayload.tryDecodeAny(rawText, allCards);
    if (sharePayload != null) {
      final result = _resolveSharePayload(
          sharePayload, allCards, ref.read(configProvider));
      ref.read(setupResultProvider.notifier).state = result;
      ref.read(_generationStatusProvider.notifier).state =
          GenerationStatus.idle;
      await ref.read(historyProvider.notifier).push(result);
      return true;
    }

    final packs = await ref.read(translationPacksProvider.future);
    final (kingdom: kingdom, landscapes: landscapes) =
        resolveSetupText(allCards, rawText, packs: packs);
    final baseResult = SetupResult(
      kingdomCards: kingdom,
      landscapeCards: landscapes,
      archetypes: [],
      setupNotes: const [],
      selectionRationale: const ['Imported from plain text list.'],
      generatedAt: DateTime.now(),
    );
    final enriched = _heuristicEngine.enrich(
        _importTableSetup(baseResult, allCards, ref.read(configProvider)));

    ref.read(setupResultProvider.notifier).state = enriched;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
    await ref.read(historyProvider.notifier).push(enriched);
    return true;
  } catch (e) {
    ref.read(_generationErrorProvider.notifier).state =
        'Import failed: ${e.toString()}';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }
}

Future<Map<String, PileReplacement>> previewPileReplacements(
    ProviderContainer ref, String slotId) async {
  final cards = await ref.read(allCardsProvider.future);
  final current = ref.read(setupResultProvider);
  if (current == null) return {};
  return _replacementOptions(cards, ref.read(configProvider), current, slotId);
}

Map<String, PileReplacement> _replacementOptions(List<KingdomCard> cards,
        ConfigState config, SetupResult current, String slotId,
        {String? incomingSlotId}) =>
    _setupEngine.replacementOptions(
      allCards: cards,
      excludedCardIds: config.excludedCardIds(cards),
      ownedExpansions: config.ownedExpansions,
      rules: current.rulesSnapshot ?? config.rules,
      current: current,
      outgoingSlotId: slotId,
      incomingSlotId: incomingSlotId,
    );

Future<bool> rerollCurrentResult(
  ProviderContainer ref, {
  bool rerollKingdom = true,
  bool rerollLandscapes = true,
  String? replaceSlotId,
  String? incomingSlotId,
}) async {
  final current = ref.read(setupResultProvider);
  if (current == null ||
      ref.read(generationStatusProvider) == GenerationStatus.loading) {
    return false;
  }

  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;

  try {
    final allRaw = await ref.read(allCardsProvider.future);
    final config = ref.read(configProvider);
    final rules = current.rulesSnapshot ?? config.rules;
    final playerCount = current.playerCount ?? config.playerCount;
    final preset = GameVibePresets.byId(current.rulesSnapshot == null
        ? config.selectedPresetId
        : current.presetId);
    final SetupResult result;
    if (replaceSlotId != null) {
      final options = _replacementOptions(
          allRaw, config, current, replaceSlotId,
          incomingSlotId: incomingSlotId);
      final replacement = incomingSlotId == null && options.isNotEmpty
          ? options.values.elementAt(Random().nextInt(options.length))
          : options[incomingSlotId];
      if (replacement == null) {
        throw const SetupException(
            'No legal replacement matches this choice. Check your rules, collection, and landscape locks.',
            SetupFailureReason.requirementImpossible);
      }
      final byId = {for (final card in allRaw) card.id: card};
      final cards = [
        for (final card in current.kingdomCards)
          if ((card.pileId) != replaceSlotId) byId[card.id]!,
        ...replacement.cards,
      ];
      result = SetupResult(
        kingdomCards: _sortImportedKingdomCards(cards),
        landscapeCards: replacement.landscapes,
        archetypes: const [],
        setupChoices: replacement.setupChoices,
        setupNotes: replacement.setupNotes,
        selectionRationale: const ['One pile was replaced.'],
        presetId: preset.id,
        generatedAt: DateTime.now(),
      );
    } else {
      result = _setupEngine.generate(
        allCards: allRaw,
        excludedCardIds: config.excludedCardIds(allRaw),
        ownedExpansions: config.ownedExpansions,
        rules: rules,
        preset: preset,
        previousSetupChoices: current.setupChoices,
        recentSlots: config.preferFreshPiles && rerollKingdom
            ? await _recentSlots(ref.read(historyServiceProvider))
            : const {},
        lockedKingdomCards: rerollKingdom
            ? current.kingdomCards
                .where((card) => current.isSlotLocked(card.pileId))
                .toList()
            : current.kingdomCards,
        lockedLandscapeCards: rerollLandscapes
            ? current.landscapeCards
                .where((card) => current.isLandscapeLocked(card.id))
                .toList()
            : current.landscapeCards,
      );
    }

    final enriched = _heuristicEngine.enrich(result).copyWith(
          lockedSlotIds: current.lockedSlotIds,
          lockedLandscapeIds: current.lockedLandscapeIds,
          rulesSnapshot: rules,
          playerCount: playerCount,
          platinumColonyChoice: current.platinumColonyChoice,
          sheltersChoice: current.sheltersChoice,
        );
    ref.read(_lastRerollProvider.notifier).state =
        (before: current, after: enriched);
    ref.read(setupResultProvider.notifier).state = enriched;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
    ref.read(historyProvider.notifier).push(enriched);
    return true;
  } on SetupException catch (e) {
    ref.read(_generationErrorProvider.notifier).state = e.message;
    ref.read(_generationReasonProvider.notifier).state = e.reason;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  } catch (e) {
    ref.read(_generationErrorProvider.notifier).state =
        'Unexpected error: ${e.toString()}';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }
}

void toggleKingdomSlotLock(WidgetRef ref, String slotId) {
  final current = ref.read(setupResultProvider);
  if (current == null) return;
  final updated = Set<String>.from(current.lockedSlotIds);
  if (updated.contains(slotId)) {
    updated.remove(slotId);
  } else {
    updated.add(slotId);
  }
  ref.read(setupResultProvider.notifier).state =
      current.copyWith(lockedSlotIds: updated);
}

void toggleLandscapeLock(WidgetRef ref, String cardId) {
  final current = ref.read(setupResultProvider);
  if (current == null) return;
  final updated = Set<String>.from(current.lockedLandscapeIds);
  if (updated.contains(cardId)) {
    updated.remove(cardId);
  } else {
    updated.add(cardId);
  }
  ref.read(setupResultProvider.notifier).state =
      current.copyWith(lockedLandscapeIds: updated);
}

void clearAllLocks(WidgetRef ref) {
  final current = ref.read(setupResultProvider);
  if (current == null) return;
  ref.read(setupResultProvider.notifier).state = current.copyWith(
    lockedSlotIds: {},
    lockedLandscapeIds: {},
  );
}

SetupResult restoreKingdom(WidgetRef ref, SetupResult saved) {
  final catalogue = ref.read(allCardsProvider).valueOrNull;
  var result = saved;
  if (catalogue != null) {
    final byId = {for (final card in catalogue) card.id: card};
    result = _heuristicEngine.enrich(_importTableSetup(
        saved.copyWith(kingdomCards: [
          for (final card in saved.kingdomCards) byId[card.id] ?? card
        ], landscapeCards: [
          for (final card in saved.landscapeCards) byId[card.id] ?? card
        ]),
        catalogue,
        ref.read(configProvider)));
  } else if (saved.setupNotes.isEmpty) {
    result = saved.copyWith(
        setupNotes: _setupEngine.generateSetupNotes(
            saved.kingdomCards, saved.landscapeCards));
  }
  ref.read(_lastRerollProvider.notifier).state = null;
  clearGenerationFeedback(ref);
  ref.read(setupResultProvider.notifier).state = result;
  return result;
}

String encodeSharePayload(SetupResult result) {
  try {
    return ShareCodebook.encode(
      kingdomSlotKeys:
          ShareCodebook.extractKingdomSlotKeys(result.kingdomCards),
      landscapeIds: ShareCodebook.extractLandscapeIds(result.landscapeCards),
    );
  } on ArgumentError {
    // The ID-based format also supports cards added after KF2 was published.
    return SharePayload(
      kingdomCardIds: result.kingdomCards.map((card) => card.id).toList(),
      landscapeCardIds: result.landscapeCards.map((card) => card.id).toList(),
    ).encode();
  }
}

String encodeFullSetup(SetupResult result) => SharePayload(
      kingdomCardIds: result.kingdomCards.map((card) => card.id).toList(),
      landscapeCardIds: result.landscapeCards.map((card) => card.id).toList(),
      presetId: result.presetId,
      rulesSnapshot: result.rulesSnapshot ?? const SetupRules(),
      playerCount: result.playerCount ?? 2,
      hasSettings: result.rulesSnapshot != null && result.playerCount != null,
      setupChoices: result.setupChoices,
      platinumColonyChoice: result.platinumColonyChoice,
      sheltersChoice: result.sheltersChoice,
    ).encode();

SetupResult resolveSharedKingdom(
    String code, List<KingdomCard> allCards, ConfigState config) {
  final payload = SharePayload.tryDecodeAny(code, allCards);
  if (payload == null) throw const FormatException('Invalid share code.');
  return _resolveSharePayload(payload, allCards, config);
}

SetupResult _resolveSharePayload(
    SharePayload payload, List<KingdomCard> allCards, ConfigState config) {
  if (payload.version != 1 && payload.version != 2) {
    throw const FormatException('Unsupported share-code version.');
  }
  final byId = {for (final card in allCards) card.id: card};
  final kingdom = <KingdomCard>[];
  final landscape = <KingdomCard>[];

  for (final id in payload.kingdomCardIds) {
    final card = byId[id];
    if (card == null) throw FormatException('Unknown kingdom card: $id');
    kingdom.add(card);
  }
  for (final id in payload.landscapeCardIds) {
    final card = byId[id];
    if (card == null) throw FormatException('Unknown landscape card: $id');
    landscape.add(card);
  }

  if (kingdom.isEmpty) {
    throw const FormatException(
        'Share code could not be resolved with the current card database.');
  }

  validateImportedKingdom(allCards, kingdom, landscapes: landscape);
  final sortedKingdom = _sortImportedKingdomCards(kingdom);
  final sortedLandscape = _sortImportedLandscapeCards(landscape);

  final baseResult = SetupResult(
    kingdomCards: sortedKingdom,
    landscapeCards: sortedLandscape,
    archetypes: const [],
    setupNotes: const [],
    setupChoices: payload.setupChoices,
    platinumColonyChoice: payload.platinumColonyChoice,
    sheltersChoice: payload.sheltersChoice,
    selectionRationale: [
      if (payload.presetId != null)
        'Imported from a shared ${GameVibePresets.byId(payload.presetId).name} kingdom.'
      else
        'Imported from a shared kingdom code.',
    ],
    presetId: payload.presetId,
    rulesSnapshot: payload.hasSettings ? payload.rulesSnapshot : null,
    playerCount: payload.hasSettings ? payload.playerCount.clamp(2, 6) : null,
    generatedAt: DateTime.now(),
  );
  return _heuristicEngine
      .enrich(_importTableSetup(baseResult, allCards, config, validate: true));
}

SetupResult _importTableSetup(
    SetupResult result, List<KingdomCard> catalogue, ConfigState config,
    {bool validate = false}) {
  final sharedTargets = result.setupChoices.values.toSet();
  final expansions = {
    ...config.ownedExpansions,
    ...result.kingdomCards.map((card) => card.expansion),
    ...result.landscapeCards.map((card) => card.expansion),
    ...catalogue
        .where((card) => sharedTargets.contains(card.id))
        .map((card) => card.expansion),
  };
  final sharedSlots = catalogue
      .where((card) =>
          sharedTargets.contains(card.id) ||
          ((card.id == 'knights' || card.id == 'castles') &&
              card.pileCardIds.any(sharedTargets.contains)))
      .map((card) => card.pileId)
      .toSet();
  final eligible = _setupEngine.eligibleKingdomPool(
    catalogue,
    expansions,
    const SetupRules(),
    excludedCardIds: {
      for (final card in catalogue)
        if (!config.ownsCard(card) && !sharedSlots.contains(card.pileId))
          card.id,
    },
  );
  return _setupEngine.completeTableSetup(result, eligible,
      previous: result.setupChoices,
      validatePrevious: validate,
      catalogue: catalogue,
      landscapePool: [
        for (final card in catalogue)
          if (card.isLandscape &&
              expansions.contains(card.expansion) &&
              !config.disabledCardIds.contains(card.id))
            card,
      ]);
}

List<KingdomCard> _sortImportedKingdomCards(List<KingdomCard> cards) {
  final slotInfo = <String, ({int cost, String name})>{};
  for (final card in cards) {
    final slotId = card.pileId;
    final current = slotInfo[slotId];
    if (current == null ||
        card.cost < current.cost ||
        (card.cost == current.cost && card.name.compareTo(current.name) < 0)) {
      slotInfo[slotId] = (cost: card.cost, name: card.name);
    }
  }

  final sorted = [...cards];
  sorted.sort((a, b) {
    final aInfo = slotInfo[a.pileId]!;
    final bInfo = slotInfo[b.pileId]!;
    final slotCost = aInfo.cost.compareTo(bInfo.cost);
    if (slotCost != 0) return slotCost;
    final slotName = aInfo.name.compareTo(bInfo.name);
    if (slotName != 0) return slotName;
    final cost = a.cost.compareTo(b.cost);
    if (cost != 0) return cost;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

List<KingdomCard> _sortImportedLandscapeCards(List<KingdomCard> cards) {
  final sorted = [...cards];
  sorted.sort((a, b) {
    final type = _landscapeSortOrder(a).compareTo(_landscapeSortOrder(b));
    if (type != 0) return type;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

int _landscapeSortOrder(KingdomCard card) {
  if (card.isEvent) return 0;
  if (card.isLandmark) return 1;
  if (card.isProject) return 2;
  if (card.isWay) return 3;
  if (card.isAlly) return 4;
  if (card.isProphecy) return 5;
  if (card.isTrait) return 6;
  return 7;
}

// ── Text parsing ──────────────────────────────────────────────────────────

List<String> parseKingdomText(String text) => parseSetupText(text).kingdom;

/// Accepts numbered exports, one name per line, or a comma-separated list.
({List<String> kingdom, List<String> landscapes}) parseSetupText(String text) {
  final sections = text.split(
      RegExp(r'^\s*Landscapes:\s*$', multiLine: true, caseSensitive: false));

  List<String> parseNames(String section) {
    final lines = section
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final numbered = RegExp(r'^\d+\.\s+(.+?)(?:\s+\([^)]+\))?$');
    final exported = lines
        .map(numbered.firstMatch)
        .whereType<RegExpMatch>()
        .map((match) => match.group(1)!)
        .toList();
    if (exported.isNotEmpty) return exported;
    if (lines.length != 1) return lines;
    return lines.single
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  return (
    kingdom: parseNames(sections.first),
    landscapes: sections.skip(1).expand(parseNames).toList(),
  );
}

/// Resolves and validates the same selection for preview and import.
({List<KingdomCard> kingdom, List<KingdomCard> landscapes}) resolveSetupText(
  List<KingdomCard> allCards,
  String text, {
  List<TranslationPack> packs = const [],
}) {
  final (kingdom: names, landscapes: landscapeNames) = parseSetupText(text);
  if (names.length != 10) {
    throw FormatException('Enter 10 pile names. Found ${names.length}.');
  }
  final resolution = resolveImportedKingdomCards(allCards, names, packs: packs);
  final landscapesByName =
      _importNames(allCards.where((card) => card.isLandscape), packs);
  final landscapes = <KingdomCard>[];
  final notFound = [...resolution.notFound];
  for (final name in landscapeNames) {
    final card = landscapesByName[name.toLowerCase()];
    if (card == null) {
      notFound.add(name);
    } else {
      landscapes.add(card);
    }
  }
  if (notFound.isNotEmpty) {
    throw FormatException('Unknown card names: ${notFound.join(', ')}.');
  }
  validateImportedKingdom(allCards, resolution.cards, landscapes: landscapes);
  return (kingdom: resolution.cards, landscapes: landscapes);
}

/// Resolves imported kingdom-list labels back into cards.
///
/// Supports split-pile labels such as `Sauna / Avanto` by expanding them back
/// into their constituent cards.
({List<KingdomCard> cards, List<String> notFound}) resolveImportedKingdomCards(
  List<KingdomCard> allCards,
  List<String> importedNames, {
  List<TranslationPack> packs = const [],
}) {
  final byLowerName =
      _importNames(allCards.where((c) => c.isKingdomCard), packs);
  final cards = <KingdomCard>[];
  final notFound = <String>[];

  for (final rawName in importedNames) {
    final parts = byLowerName.containsKey(rawName.toLowerCase())
        ? [rawName]
        : rawName
            .split('/')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) {
      notFound.add(rawName);
      continue;
    }

    var matchedAny = false;
    for (final part in parts) {
      final card = byLowerName[part.toLowerCase()];
      if (card == null) {
        if (parts.length == 1) {
          notFound.add(rawName);
        } else {
          notFound.add(part);
        }
        continue;
      }
      matchedAny = true;
      cards.add(card);
    }

    if (!matchedAny && !notFound.contains(rawName)) {
      notFound.add(rawName);
    }
  }

  return (cards: cards, notFound: notFound);
}

Map<String, KingdomCard> _importNames(
    Iterable<KingdomCard> cards, List<TranslationPack> packs) {
  final aliases = <String, Set<KingdomCard>>{};
  // Printed translations take precedence over legacy alternate names.
  final localizedNames = {
    for (final card in cards)
      for (final pack in packs)
        if (pack.lookup(card.id) case final entry?)
          entry.name.trim().toLowerCase(),
  };
  for (final card in cards) {
    final names = [
      ...card.alternateNames
          .where((name) => !localizedNames.contains(name.trim().toLowerCase())),
      for (final pack in packs)
        if (pack.lookup(card.id) case final entry?) entry.name,
    ];
    for (final name in names) {
      final alias = name.trim().toLowerCase();
      if (alias.isNotEmpty) {
        (aliases[alias] ??= {}).add(card);
      }
    }
  }
  return {
    for (final entry in aliases.entries)
      if (entry.value.length == 1) entry.key: entry.value.single,
    for (final card in cards) card.name.toLowerCase(): card,
  };
}
