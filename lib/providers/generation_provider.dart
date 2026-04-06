import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/heuristic_engine.dart';
import '../controllers/setup_engine.dart';
import '../controllers/setup_exception.dart';
import '../models/setup_result.dart';
import 'card_data_providers.dart';
import 'config_provider.dart';

// ── Last generated result (null until first run) ──────────────────────────

final setupResultProvider = StateProvider<SetupResult?>((ref) => null);

// ── Generation status ─────────────────────────────────────────────────────

enum GenerationStatus { idle, loading, error }

final _generationStatusProvider =
    StateProvider<GenerationStatus>((ref) => GenerationStatus.idle);

final _generationErrorProvider = StateProvider<String?>((ref) => null);

// Convenience read-only providers for the UI
final generationStatusProvider =
    Provider<GenerationStatus>((ref) => ref.watch(_generationStatusProvider));

final generationErrorProvider =
    Provider<String?>((ref) => ref.watch(_generationErrorProvider));

// ── Generation action ─────────────────────────────────────────────────────

/// Singletons reused across calls — both are stateless.
final _setupEngine    = SetupEngine();
final _heuristicEngine = HeuristicEngine();

/// Call this from a button handler to run the full pipeline.
///
/// Returns `true` on success, `false` on [SetupException].
/// Updates [setupResultProvider] and [generationStatusProvider] reactively.
Future<bool> generateKingdom(WidgetRef ref) async {
  ref.read(_generationStatusProvider.notifier).state = GenerationStatus.loading;
  ref.read(_generationErrorProvider.notifier).state  = null;

  try {
    // Load catalogue (cached after first call)
    final allRaw = await ref.read(allCardsProvider.future);
    final config = ref.read(configProvider);

    // Stamp disabled flags from the ban list onto card objects
    final cards = allRaw
        .map((c) => config.isCardDisabled(c.id)
            ? c.copyWith(isDisabled: true)
            : c)
        .toList();

    final result = _setupEngine.generate(
      allCards:        cards,
      ownedExpansions: config.ownedExpansions,
      rules:           config.rules,
    );

    final enriched = _heuristicEngine.enrich(result);

    ref.read(setupResultProvider.notifier).state      = enriched;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.idle;
    return true;
  } on SetupException catch (e) {
    ref.read(_generationErrorProvider.notifier).state  = e.message;
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  } catch (e) {
    ref.read(_generationErrorProvider.notifier).state  =
        'Unexpected error: ${e.toString()}';
    ref.read(_generationStatusProvider.notifier).state = GenerationStatus.error;
    return false;
  }
}

// ── Derived: available card count for the current config ─────────────────
// Used to warn the user if they have fewer than 10 selectable cards.

final availableCardCountProvider = Provider<AsyncValue<int>>((ref) {
  final allAsync = ref.watch(allCardsProvider);
  final config   = ref.watch(configProvider);

  return allAsync.whenData((all) {
    return all.where((c) =>
        config.isExpansionOwned(c.expansion) &&
        c.isKingdomCard &&
        !config.isCardDisabled(c.id)).length;
  });
});
