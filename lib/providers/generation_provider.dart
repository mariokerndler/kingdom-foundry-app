import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/heuristic_engine.dart';
import '../controllers/setup_engine.dart';
import '../controllers/setup_exception.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/share_codebook.dart';
import '../models/share_payload.dart';
import '../models/setup_result.dart';
import 'card_data_providers.dart';
import 'config_provider.dart';
import 'history_provider.dart';

// ── Last generated result (null until first run) ──────────────────────────

final setupResultProvider = StateProvider<SetupResult?>((ref) => null);

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

// ── Shared engine singletons ──────────────────────────────────────────────

/// Singletons reused across calls — both are stateless.
final _setupEngine = SetupEngine();
final _heuristicEngine = HeuristicEngine();

// ── Generate action ───────────────────────────────────────────────────────

/// Call this from a button handler to run the full pipeline.
///
/// Returns `true` on success, `false` on [SetupException].
/// Updates [setupResultProvider] and [generationStatusProvider] reactively.
Future<bool> generateKingdom(WidgetRef ref) async {
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;

  try {
    final allRaw = await ref.read(allCardsProvider.future);
    final config = ref.read(configProvider);

    // Stamp disabled flags from the ban list onto card objects
    final cards = allRaw
        .map((c) =>
            config.isCardDisabled(c.id) ? c.copyWith(isDisabled: true) : c)
        .toList();

    final result = _setupEngine.generate(
      allCards: cards,
      ownedExpansions: config.ownedExpansions,
      rules: config.rules,
      preset: GameVibePresets.byId(config.selectedPresetId),
    );

    final enriched = _heuristicEngine.enrich(result);

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
      return _importSharePayload(ref, sharePayload);
    }

    final names = parseKingdomText(rawText);

    if (names.length != 10) {
      ref.read(_generationErrorProvider.notifier).state =
          'Need exactly 10 cards but found ${names.length}. '
          'Make sure you paste the complete kingdom list.';
      ref.read(_generationStatusProvider.notifier).state =
          GenerationStatus.error;
      return false;
    }

    final resolution = resolveImportedKingdomCards(allCards, names);
    final kingdom = resolution.cards;
    final notFound = resolution.notFound;

    if (notFound.isNotEmpty) {
      final missing = notFound.join(', ');
      ref.read(_generationErrorProvider.notifier).state =
          'Could not find in the card database: $missing.\n\n'
          'The app may not have data for that expansion yet.';
      ref.read(_generationStatusProvider.notifier).state =
          GenerationStatus.error;
      return false;
    }

    final baseResult = SetupResult(
      kingdomCards: kingdom,
      archetypes: [],
      setupNotes: [],
      selectionRationale: const ['Imported from plain text list.'],
      generatedAt: DateTime.now(),
    );
    final enriched = _heuristicEngine.enrich(baseResult);

    ref.read(setupResultProvider.notifier).state = enriched;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
    return true;
  } catch (e) {
    ref.read(_generationErrorProvider.notifier).state =
        'Import failed: ${e.toString()}';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }
}

Future<bool> rerollCurrentResult(
  WidgetRef ref, {
  bool rerollKingdom = true,
  bool rerollLandscapes = true,
}) async {
  final current = ref.read(setupResultProvider);
  if (current == null) return false;

  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state = null;
  ref.read(_generationReasonProvider.notifier).state = null;

  try {
    final allRaw = await ref.read(allCardsProvider.future);
    final config = ref.read(configProvider);
    final preset = GameVibePresets.byId(config.selectedPresetId);
    final cards = allRaw
        .map((c) =>
            config.isCardDisabled(c.id) ? c.copyWith(isDisabled: true) : c)
        .toList();

    final lockedKingdomCards = rerollKingdom
        ? current.kingdomCards
            .where((card) =>
                current.lockedSlotIds.contains(card.splitPileId ?? card.id))
            .toList()
        : current.kingdomCards;
    final lockedLandscapeCards = rerollLandscapes
        ? current.landscapeCards
            .where((card) => current.lockedLandscapeIds.contains(card.id))
            .toList()
        : current.landscapeCards;

    final result = _setupEngine.generate(
      allCards: cards,
      ownedExpansions: config.ownedExpansions,
      rules: config.rules,
      preset: preset,
      lockedKingdomCards: lockedKingdomCards,
      lockedLandscapeCards: lockedLandscapeCards,
    );

    final enriched = _heuristicEngine.enrich(result);
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

String encodeSharePayload(SetupResult result) {
  return ShareCodebook.encode(
    kingdomSlotKeys: ShareCodebook.extractKingdomSlotKeys(result.kingdomCards),
    landscapeIds: ShareCodebook.extractLandscapeIds(result.landscapeCards),
  );
}

Future<bool> _importSharePayload(WidgetRef ref, SharePayload payload) async {
  final allCards = await ref.read(allCardsProvider.future);
  final byId = {for (final card in allCards) card.id: card};
  final kingdom = <KingdomCard>[];
  final landscape = <KingdomCard>[];

  for (final id in payload.kingdomCardIds) {
    final card = byId[id];
    if (card != null) kingdom.add(card);
  }
  for (final id in payload.landscapeCardIds) {
    final card = byId[id];
    if (card != null) landscape.add(card);
  }

  if (kingdom.isEmpty) {
    ref.read(_generationErrorProvider.notifier).state =
        'Share code could not be resolved with the current card database.';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }

  final sortedKingdom = _sortImportedKingdomCards(kingdom);
  final sortedLandscape = _sortImportedLandscapeCards(landscape);

  final baseResult = SetupResult(
    kingdomCards: sortedKingdom,
    landscapeCards: sortedLandscape,
    archetypes: const [],
    setupNotes: payload.notes,
    selectionRationale: [
      if (payload.presetId != null)
        'Imported from a shared ${GameVibePresets.byId(payload.presetId).name} kingdom.'
      else
        'Imported from a shared kingdom code.',
    ],
    presetId: payload.presetId,
    generatedAt: DateTime.now(),
  );
  final enriched = _heuristicEngine.enrich(baseResult);
  ref.read(setupResultProvider.notifier).state = enriched;
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
  return true;
}

List<KingdomCard> _sortImportedKingdomCards(List<KingdomCard> cards) {
  final slotInfo = <String, ({int cost, String name})>{};
  for (final card in cards) {
    final slotId = card.splitPileId ?? card.id;
    final current = slotInfo[slotId];
    if (current == null ||
        card.cost < current.cost ||
        (card.cost == current.cost && card.name.compareTo(current.name) < 0)) {
      slotInfo[slotId] = (cost: card.cost, name: card.name);
    }
  }

  final sorted = [...cards];
  sorted.sort((a, b) {
    final aInfo = slotInfo[a.splitPileId ?? a.id]!;
    final bInfo = slotInfo[b.splitPileId ?? b.id]!;
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

/// Extracts card names from a shared kingdom list.
///
/// Expects lines in the format produced by the copy action:
/// ```
/// 1. Village ($3)
/// 2. Smithy ($4)
/// ```
/// Extra whitespace and unrecognised lines are silently ignored.
/// Exported so the import dialog can show a live preview as the user pastes.
List<String> parseKingdomText(String text) {
  // Matches: "<number>. <name> (<cost>)"
  // Cost can contain $, digits, P, D, + — use [^)] to capture anything.
  final re = RegExp(r'^\d+\.\s+(.+?)\s+\([^)]+\)$');
  return text
      .replaceAll('\r\n', '\n')
      .split('\n')
      .map((line) => re.firstMatch(line.trim()))
      .whereType<RegExpMatch>()
      .map((m) => m.group(1)!)
      .toList();
}

/// Resolves imported kingdom-list labels back into cards.
///
/// Supports split-pile labels such as `Sauna / Avanto` by expanding them back
/// into their constituent cards.
({List<KingdomCard> cards, List<String> notFound}) resolveImportedKingdomCards(
  List<KingdomCard> allCards,
  List<String> importedNames,
) {
  final byLowerName = {
    for (final card in allCards.where((c) => c.isKingdomCard))
      card.name.toLowerCase(): card,
  };
  final cards = <KingdomCard>[];
  final notFound = <String>[];
  final seenIds = <String>{};

  for (final rawName in importedNames) {
    final parts = rawName
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
      if (seenIds.add(card.id)) {
        cards.add(card);
      }
    }

    if (!matchedAny && !notFound.contains(rawName)) {
      notFound.add(rawName);
    }
  }

  return (cards: cards, notFound: notFound);
}

// ── Derived: available card count ─────────────────────────────────────────

/// Used to warn the user if they have fewer than 10 selectable cards.
final availableCardCountProvider = Provider<AsyncValue<int>>((ref) {
  final allAsync = ref.watch(allCardsProvider);
  final config = ref.watch(configProvider);

  return allAsync.whenData((all) => all
      .where((c) =>
          config.isExpansionOwned(c.expansion) &&
          c.isKingdomCard &&
          !config.isCardDisabled(c.id))
      .length);
});
