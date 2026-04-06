import 'dart:math';

import '../models/card_tag.dart';
import '../models/dominion_card.dart';
import '../models/expansion.dart';
import '../models/setup_result.dart';
import '../models/setup_rules.dart';
import 'setup_exception.dart';

/// Orchestrates the four-step kingdom generation pipeline.
///
/// Usage:
/// ```dart
/// final engine = SetupEngine();
/// final result = engine.generate(
///   allCards:         cardRepository.cards,
///   ownedExpansions:  {Expansion.base, Expansion.intrigue},
///   rules:            SetupRules(requireVillage: true),
/// );
/// ```
///
/// Throws [SetupException] when a valid kingdom cannot be produced.
class SetupEngine {
  final Random _rng;

  SetupEngine({Random? random}) : _rng = random ?? Random();

  // ===========================================================================
  // Public API
  // ===========================================================================

  SetupResult generate({
    required List<DominionCard> allCards,
    required Set<Expansion> ownedExpansions,
    required SetupRules rules,
  }) {
    // ── Step A ── Expansion filter ──────────────────────────────────────────
    final pool = _stepAExpansionFilter(allCards, ownedExpansions);

    // ── Step B ── Manual exclusions ─────────────────────────────────────────
    _stepBRemoveDisabled(pool);

    // ── Step C ── Global rule modifiers ─────────────────────────────────────
    _stepCApplyRules(pool, rules);

    // Validate before selection — give a clear message.
    if (pool.length < 10) {
      throw SetupException(
        'Only ${pool.length} card${pool.length == 1 ? '' : 's'} remain after '
        'filtering — need at least 10. Try enabling more expansions or '
        'relaxing the active rules.',
        SetupFailureReason.poolTooSmall,
      );
    }

    // ── Step D ── Selection algorithm ────────────────────────────────────────
    final (kingdom, lockedCount) = _stepDSelect(pool, rules);

    // ── Supplement ── Setup notes ────────────────────────────────────────────
    final notes = _generateSetupNotes(kingdom, ownedExpansions);

    return SetupResult(
      kingdomCards: kingdom,
      archetypes:   const [],   // populated later by HeuristicEngine
      setupNotes:   notes,
      generatedAt:  DateTime.now(),
    );
  }

  // ===========================================================================
  // Step A — Expansion filter
  // ===========================================================================

  /// Returns a mutable list of kingdom cards from the owned expansions.
  List<DominionCard> _stepAExpansionFilter(
    List<DominionCard> all,
    Set<Expansion> owned,
  ) {
    return all
        .where((c) => owned.contains(c.expansion) && c.isKingdomCard)
        .toList();
  }

  // ===========================================================================
  // Step B — Manual exclusions
  // ===========================================================================

  void _stepBRemoveDisabled(List<DominionCard> pool) {
    pool.removeWhere((c) => c.isDisabled);
  }

  // ===========================================================================
  // Step C — Rule modifiers
  // ===========================================================================

  void _stepCApplyRules(List<DominionCard> pool, SetupRules rules) {
    pool.removeWhere((c) {
      if (rules.noAttacks  && c.isAttack)           return true;
      if (rules.noDuration && c.isDuration)          return true;
      if (rules.noPotions  && c.potionCost)          return true;
      if (rules.noDebt     && c.debtCost != null)    return true;
      if (rules.maxCost != null && c.cost > rules.maxCost!) return true;
      return false;
    });
  }

  // ===========================================================================
  // Step D — Weighted selection algorithm
  //
  // Design: two-phase approach.
  //
  // Phase 1 — Slot reservation (hard requirements).
  //   Each "require" rule claims one slot by picking a random qualifying card
  //   from the shuffled pool and locking it into the kingdom. Locked cards
  //   cannot be displaced in the variety-enforcement pass.
  //
  // Phase 2 — Random fill.
  //   The remaining (10 − locked) slots are filled from the shuffled pool,
  //   which is already random — no additional weighting needed here.
  //
  // Phase 3 — Expansion variety enforcement (optional).
  //   If minExpansionVariety > 1, swap non-locked cards with cards from
  //   under-represented expansions until the constraint is met.
  //
  // Returns the 10 selected cards and the number of locked (required) cards.
  // ===========================================================================

  (List<DominionCard>, int) _stepDSelect(
    List<DominionCard> pool,
    SetupRules rules,
  ) {
    // Shuffle once — used for both phase 1 candidate picking and phase 2 fill.
    final shuffled = [...pool]..shuffle(_rng);

    final kingdom = <DominionCard>[];   // final selection
    final locked  = <DominionCard>[];   // required-slot cards (cannot be swapped)

    // ── Phase 1: required slots ─────────────────────────────────────────────

    void reserveSlot(
      bool condition,
      bool Function(DominionCard) matcher,
      String ruleName,
    ) {
      if (!condition) return;
      final candidates = shuffled.where(matcher).toList();
      if (candidates.isEmpty) {
        throw SetupException(
          'Cannot satisfy "$ruleName": no matching cards remain after '
          'filtering. Try enabling more expansions or disabling conflicting '
          'rules.',
          SetupFailureReason.requirementImpossible,
        );
      }
      final pick = candidates[_rng.nextInt(candidates.length)];
      locked.add(pick);
      kingdom.add(pick);
      shuffled.remove(pick);
    }

    reserveSlot(
      rules.requireVillage,
      (c) => c.hasTag(CardTag.villageEffect) || c.hasTag(CardTag.plusTwoActions),
      'Require Village',
    );

    reserveSlot(
      rules.requireTrashing,
      (c) => c.hasTag(CardTag.trashCards) || c.hasTag(CardTag.trashForBenefit),
      'Require Trashing',
    );

    reserveSlot(
      rules.requirePlusBuy,
      (c) => c.hasTag(CardTag.plusBuy),
      'Require +Buy',
    );

    // ── Phase 2: random fill ────────────────────────────────────────────────

    for (final card in shuffled) {
      if (kingdom.length >= 10) break;
      kingdom.add(card);
    }

    if (kingdom.length < 10) {
      // Shouldn't reach here because we validated pool.length >= 10 earlier,
      // but guard for safety.
      throw SetupException(
        'Pool exhausted before 10 cards could be selected '
        '(${kingdom.length}/10). This is likely a bug.',
        SetupFailureReason.poolTooSmall,
      );
    }

    // ── Phase 3: expansion variety ──────────────────────────────────────────

    if (rules.minExpansionVariety > 1) {
      _enforceExpansionVariety(
        kingdom:     kingdom,
        locked:      locked,
        remainder:   shuffled.skip(10 - locked.length).toList(), // unused cards
        minVariety:  rules.minExpansionVariety,
        ownedCount:  pool.map((c) => c.expansion).toSet().length,
      );
    }

    // Sort by cost (ascending) for a natural display order.
    kingdom.sort((a, b) {
      final costCmp = a.cost.compareTo(b.cost);
      return costCmp != 0 ? costCmp : a.name.compareTo(b.name);
    });

    return (kingdom, locked.length);
  }

  // ===========================================================================
  // Expansion variety enforcement
  // ===========================================================================

  void _enforceExpansionVariety({
    required List<DominionCard> kingdom,
    required List<DominionCard> locked,
    required List<DominionCard> remainder,
    required int minVariety,
    required int ownedCount,
  }) {
    // If the user owns fewer expansions than the min, it's impossible.
    if (ownedCount < minVariety) {
      throw SetupException(
        'Cannot reach $minVariety expansion variety — only $ownedCount '
        'expansion${ownedCount == 1 ? '' : 's'} enabled.',
        SetupFailureReason.varietyImpossible,
      );
    }

    // Swappable = non-locked cards in the kingdom.
    final swappable = kingdom.where((c) => !locked.contains(c)).toList();
    remainder.shuffle(_rng);

    int attempts = 0;

    while (attempts < 30) {
      final presentExpansions = kingdom.map((c) => c.expansion).toSet();
      if (presentExpansions.length >= minVariety) break;

      // Find a candidate from a new expansion.
      final candidate = remainder.cast<DominionCard?>().firstWhere(
        (c) => !presentExpansions.contains(c!.expansion),
        orElse: () => null,
      );
      if (candidate == null) break; // no card from a new expansion exists

      // Find a swappable card to evict (pick randomly among same expansion as
      // the most-represented one to reduce bias).
      final overExpansion = _mostRepresentedExpansion(kingdom, locked);
      final evictCandidates = swappable
          .where((c) => c.expansion == overExpansion)
          .toList();

      final evict = evictCandidates.isNotEmpty
          ? evictCandidates[_rng.nextInt(evictCandidates.length)]
          : swappable[_rng.nextInt(swappable.length)];

      kingdom.remove(evict);
      kingdom.add(candidate);
      swappable.remove(evict);
      swappable.add(candidate);
      remainder.remove(candidate);
      remainder.add(evict);
      remainder.shuffle(_rng);

      attempts++;
    }
  }

  /// Returns the expansion that has the most non-locked cards in [kingdom].
  Expansion _mostRepresentedExpansion(
    List<DominionCard> kingdom,
    List<DominionCard> locked,
  ) {
    final counts = <Expansion, int>{};
    for (final c in kingdom) {
      if (!locked.contains(c)) {
        counts[c.expansion] = (counts[c.expansion] ?? 0) + 1;
      }
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // ===========================================================================
  // Setup notes
  // ===========================================================================

  List<String> _generateSetupNotes(
    List<DominionCard> kingdom,
    Set<Expansion> owned,
  ) {
    final notes = <String>[];
    final kingdomExpansions = kingdom.map((c) => c.expansion).toSet();

    // Prosperity: optional Platinum & Colony
    final hasProsperity = kingdomExpansions.any((e) =>
        e == Expansion.prosperity || e == Expansion.prosperitySecondEdition);
    if (hasProsperity) {
      notes.add(
        'Prosperity cards present: you may replace Gold→Platinum and '
        'Province→Colony for a higher-powered game.',
      );
    }

    // Alchemy: Potion supply pile
    if (kingdom.any((c) => c.potionCost)) {
      notes.add('Potion-cost cards present: add the Potion supply pile (\$4).');
    }

    // Empires / Allies debt cards
    if (kingdom.any((c) => c.debtCost != null)) {
      notes.add(
        'Debt cards present: prepare the Debt token supply '
        '(the coin-shaped cardboard tokens).',
      );
    }

    // Dark Ages: Shelters starting option
    if (kingdomExpansions.contains(Expansion.darkAges)) {
      notes.add(
        'Dark Ages present: optionally start with Shelters '
        '(Hovel, Necropolis, Overgrown Estate) instead of starting Estates.',
      );
    }

    // Nocturne: Heirloom swaps
    if (kingdomExpansions.contains(Expansion.nocturne)) {
      notes.add(
        'Nocturne cards present: check whether any kingdom card replaces '
        'a starting Copper with its paired Heirloom.',
      );
    }

    // Attacks with no Reactions
    final hasAttack   = kingdom.any((c) => c.isAttack);
    final hasReaction = kingdom.any((c) => c.isReaction);
    if (hasAttack && !hasReaction) {
      notes.add(
        'Attacks present with no Reaction cards — all players are equally '
        'exposed. Prioritise Attack mitigation (e.g., Moat from Base if '
        'available) or race to attack first.',
      );
    }

    // Curses with no trashing
    final hasCurseAttack = kingdom.any((c) => c.hasTag(CardTag.curse));
    final hasTrashing    = kingdom.any((c) =>
        c.hasTag(CardTag.trashCards) || c.hasTag(CardTag.trashForBenefit));
    if (hasCurseAttack && !hasTrashing) {
      notes.add(
        'Curse-giving Attacks present with no Trashing — consider prioritising '
        'Province timing to end the game before Curses pile up.',
      );
    }

    return notes;
  }
}
