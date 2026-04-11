import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/heuristic_engine.dart';
import '../controllers/setup_engine.dart';
import '../controllers/setup_exception.dart';
import '../models/kingdom_card.dart';
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
    final names = parseKingdomText(rawText);

    if (names.length != 10) {
      ref.read(_generationErrorProvider.notifier).state =
          'Need exactly 10 cards but found ${names.length}. '
          'Make sure you paste the complete kingdom list.';
      ref.read(_generationStatusProvider.notifier).state =
          GenerationStatus.error;
      return false;
    }

    final allCards = await ref.read(allCardsProvider.future);
    final kingdom = <KingdomCard>[];
    final notFound = <String>[];

    for (final name in names) {
      final card = allCards
          .where((c) =>
              c.isKingdomCard && c.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      if (card != null) {
        kingdom.add(card);
      } else {
        notFound.add(name);
      }
    }

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
