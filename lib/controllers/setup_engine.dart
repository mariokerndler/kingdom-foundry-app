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
    final pool      = _stepAKingdomPool(allCards, ownedExpansions);
    final landscape = _stepALandscapePool(allCards, ownedExpansions);

    // ── Step B ── Manual exclusions ─────────────────────────────────────────
    _stepBRemoveDisabled(pool);

    // ── Step C ── Global rule modifiers ─────────────────────────────────────
    _stepCApplyRules(pool, rules);

    // Validate pool size. Split piles are collapsed to one representative card
    // per pile, so effective pool = unique pile slots.
    final effectiveSize = _effectivePoolSize(pool);
    if (effectiveSize < 10) {
      throw SetupException(
        'Only $effectiveSize card slot${effectiveSize == 1 ? '' : 's'} remain '
        'after filtering — need at least 10. Try enabling more expansions or '
        'relaxing the active rules.',
        SetupFailureReason.poolTooSmall,
      );
    }

    // ── Step D ── Selection algorithm ────────────────────────────────────────
    final (kingdom, lockedCount) = _stepDSelect(pool, rules);

    // ── Step E ── Landscape cards ────────────────────────────────────────────
    final landscapeResult = rules.includeLandscape
        ? _stepESelectLandscape(landscape, ownedExpansions)
        : const <DominionCard>[];

    // ── Supplement ── Setup notes ────────────────────────────────────────────
    final notes = _generateSetupNotes(kingdom, landscapeResult, ownedExpansions);

    return SetupResult(
      kingdomCards:   kingdom,
      landscapeCards: landscapeResult,
      archetypes:     const [],   // populated later by HeuristicEngine
      setupNotes:     notes,
      generatedAt:    DateTime.now(),
    );
  }

  // ===========================================================================
  // Step A — Pools
  // ===========================================================================

  /// Kingdom pool: owned, isKingdomCard. For split piles, one card per pile id
  /// (the lower-cost half) acts as the pile representative; the other is kept
  /// alongside so both are added to the kingdom when the pile is selected.
  List<DominionCard> _stepAKingdomPool(
    List<DominionCard> all,
    Set<Expansion> owned,
  ) =>
      all
          .where((c) => owned.contains(c.expansion) && c.isKingdomCard)
          .toList();

  /// Landscape pool: owned, non-kingdom (Events, Landmarks, Projects, Ways, Allies).
  List<DominionCard> _stepALandscapePool(
    List<DominionCard> all,
    Set<Expansion> owned,
  ) =>
      all
          .where((c) => owned.contains(c.expansion) && !c.isKingdomCard)
          .toList();

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
      if (rules.noAttacks  && c.isAttack)        return true;
      if (rules.noDuration && c.isDuration)       return true;
      if (rules.noPotions  && c.potionCost)       return true;
      if (rules.noDebt     && c.debtCost != null) return true;
      if (rules.maxCost != null && c.cost > rules.maxCost!) return true;
      return false;
    });
  }

  // ===========================================================================
  // Step D — Selection (split-pile aware)
  // ===========================================================================

  (List<DominionCard>, int) _stepDSelect(
    List<DominionCard> pool,
    SetupRules rules,
  ) {
    // Collapse split piles: group by splitPileId.
    // Each unique pile id becomes one "slot". Within a slot, all member cards
    // are always selected together.
    final splitGroups = <String, List<DominionCard>>{};
    final singles     = <DominionCard>[];

    for (final c in pool) {
      if (c.splitPileId != null) {
        (splitGroups[c.splitPileId!] ??= []).add(c);
      } else {
        singles.add(c);
      }
    }

    // Build a list of "pile representatives" for shuffling.
    // Each representative is the lowest-cost card in the group.
    final pileReps = <DominionCard>[
      ...singles,
      ...splitGroups.values.map(
        (g) => g.reduce((a, b) => a.cost <= b.cost ? a : b),
      ),
    ]..shuffle(_rng);

    final kingdom = <DominionCard>[];
    final locked  = <DominionCard>[];

    // ── Phase 1: required slots ─────────────────────────────────────────────

    void reserveSlot(
      bool condition,
      bool Function(DominionCard) matcher,
      String ruleName,
    ) {
      if (!condition) return;
      final candidates = pileReps.where(matcher).toList();
      if (candidates.isEmpty) {
        throw SetupException(
          'Cannot satisfy "$ruleName": no matching cards remain after '
          'filtering. Try enabling more expansions or disabling conflicting rules.',
          SetupFailureReason.requirementImpossible,
        );
      }
      final pick = candidates[_rng.nextInt(candidates.length)];
      _addPile(pick, splitGroups, kingdom);
      locked.addAll(_allCardsForRep(pick, splitGroups));
      pileReps.remove(pick);
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

    for (final rep in pileReps) {
      if (kingdom.length >= 10) break;
      _addPile(rep, splitGroups, kingdom);
    }

    if (kingdom.length < 10) {
      throw SetupException(
        'Pool exhausted before 10 cards could be selected '
        '(${kingdom.length}/10). This is likely a bug.',
        SetupFailureReason.poolTooSmall,
      );
    }

    // ── Phase 3: expansion variety ──────────────────────────────────────────

    if (rules.minExpansionVariety > 1) {
      final ownedCount = pool.map((c) => c.expansion).toSet().length;
      _enforceExpansionVariety(
        kingdom:    kingdom,
        locked:     locked,
        remainder:  pileReps.skip(10 - locked.length).toList(),
        splitGroups: splitGroups,
        minVariety: rules.minExpansionVariety,
        ownedCount: ownedCount,
      );
    }

    // Sort by cost (ascending) for natural display order.
    kingdom.sort((a, b) {
      final cmp = a.cost.compareTo(b.cost);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return (kingdom, locked.length);
  }

  /// Adds a pile representative (and all its split-pile partners) to [kingdom].
  void _addPile(
    DominionCard rep,
    Map<String, List<DominionCard>> splitGroups,
    List<DominionCard> kingdom,
  ) {
    kingdom.addAll(_allCardsForRep(rep, splitGroups));
  }

  /// Returns all cards that belong to the same pile as [rep].
  List<DominionCard> _allCardsForRep(
    DominionCard rep,
    Map<String, List<DominionCard>> splitGroups,
  ) {
    if (rep.splitPileId != null) {
      return splitGroups[rep.splitPileId!] ?? [rep];
    }
    return [rep];
  }

  /// Effective pool size = number of kingdom slots (each split pile = 1 slot).
  int _effectivePoolSize(List<DominionCard> pool) {
    final splitIds = pool
        .where((c) => c.splitPileId != null)
        .map((c) => c.splitPileId!)
        .toSet();
    final singleCount = pool.where((c) => c.splitPileId == null).length;
    return singleCount + splitIds.length;
  }

  // ===========================================================================
  // Step E — Landscape cards
  // ===========================================================================

  /// Draws the correct number of landscape cards per expansion rules.
  List<DominionCard> _stepESelectLandscape(
    List<DominionCard> pool,
    Set<Expansion> owned,
  ) {
    if (pool.isEmpty) return const [];

    final result    = <DominionCard>[];
    final shuffled  = [...pool]..shuffle(_rng);

    void draw(bool Function(DominionCard) filter, int count) {
      final candidates = shuffled.where(filter).toList();
      result.addAll(candidates.take(count.clamp(0, candidates.length)));
    }

    // Adventures / Empires: 2 Events (if any available)
    draw((c) => c.isEvent, 2);

    // Empires: 1 Landmark
    draw((c) => c.isLandmark, 1);

    // Renaissance: 2 Projects
    draw((c) => c.isProject, 2);

    // Allies: 1 Ally
    draw((c) => c.isAlly, 1);

    // Ways (Menagerie) — 1 Way; optional in real rules but we include 1
    draw((c) => c.isWay, 1);

    return result;
  }

  // ===========================================================================
  // Expansion variety enforcement
  // ===========================================================================

  void _enforceExpansionVariety({
    required List<DominionCard> kingdom,
    required List<DominionCard> locked,
    required List<DominionCard> remainder,
    required Map<String, List<DominionCard>> splitGroups,
    required int minVariety,
    required int ownedCount,
  }) {
    if (ownedCount < minVariety) {
      throw SetupException(
        'Cannot reach $minVariety expansion variety — only $ownedCount '
        'expansion${ownedCount == 1 ? '' : 's'} enabled.',
        SetupFailureReason.varietyImpossible,
      );
    }

    final swappable = kingdom.where((c) => !locked.contains(c)).toList();
    remainder.shuffle(_rng);

    for (var attempts = 0; attempts < 30; attempts++) {
      final present = kingdom.map((c) => c.expansion).toSet();
      if (present.length >= minVariety) break;

      final candidate = remainder.cast<DominionCard?>().firstWhere(
        (c) => !present.contains(c!.expansion),
        orElse: () => null,
      );
      if (candidate == null) break;

      final overExp    = _mostRepresentedExpansion(kingdom, locked);
      final evictPool  = swappable.where((c) => c.expansion == overExp).toList();
      final evict      = evictPool.isNotEmpty
          ? evictPool[_rng.nextInt(evictPool.length)]
          : swappable[_rng.nextInt(swappable.length)];

      kingdom.remove(evict);
      kingdom.add(candidate);
      swappable.remove(evict);
      swappable.add(candidate);
      remainder.remove(candidate);
      remainder.add(evict);
      remainder.shuffle(_rng);
    }
  }

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
    List<DominionCard> landscape,
    Set<Expansion> owned,
  ) {
    final notes            = <String>[];
    final kingdomExp       = kingdom.map((c) => c.expansion).toSet();
    final allPresent       = {...kingdomExp, ...landscape.map((c) => c.expansion)};

    // Prosperity: optional Platinum & Colony
    if (allPresent.any((e) =>
        e == Expansion.prosperity || e == Expansion.prosperitySecondEdition)) {
      notes.add(
        'Prosperity cards present: you may replace Gold→Platinum and '
        'Province→Colony for a higher-powered game.',
      );
    }

    // Alchemy: Potion supply pile
    if (kingdom.any((c) => c.potionCost)) {
      notes.add('Potion-cost cards present: add the Potion supply pile (\$4).');
    }

    // Empires / debt cards
    if (kingdom.any((c) => c.debtCost != null)) {
      notes.add(
        'Debt cards present: prepare the Debt token supply '
        '(the coin-shaped cardboard tokens).',
      );
    }

    // Dark Ages: Shelters
    if (kingdomExp.contains(Expansion.darkAges)) {
      notes.add(
        'Dark Ages present: optionally start with Shelters '
        '(Hovel, Necropolis, Overgrown Estate) instead of starting Estates.',
      );
    }

    // Nocturne: Heirlooms
    if (kingdomExp.contains(Expansion.nocturne)) {
      notes.add(
        'Nocturne cards present: check whether any kingdom card replaces '
        'a starting Copper with its paired Heirloom.',
      );
    }

    // Traveller chains
    for (final c in kingdom.where((c) => c.isTraveller)) {
      final chain = c.travellerChain.join(' → ');
      notes.add(
        '${c.name} is a Traveller: have the full upgrade chain available '
        '($chain) and set those cards aside before play.',
      );
    }

    // Split piles — remind players to set both halves out
    final splitIds = kingdom
        .where((c) => c.isSplitPile)
        .map((c) => c.splitPileId!)
        .toSet();
    for (final id in splitIds) {
      final pair = kingdom.where((c) => c.splitPileId == id).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));
      if (pair.length >= 2) {
        notes.add(
          'Split pile: ${pair.map((c) => c.name).join(' / ')} — place both '
          'halves in a single supply pile, lower-cost (${pair.first.name}) on top.',
        );
      }
    }

    // Attacks with no Reactions
    if (kingdom.any((c) => c.isAttack) && !kingdom.any((c) => c.isReaction)) {
      notes.add(
        'Attacks present with no Reaction cards — all players are equally '
        'exposed. Race to attack first or watch for Moat in the base supply.',
      );
    }

    // Curses with no trashing
    if (kingdom.any((c) => c.hasTag(CardTag.curse)) &&
        !kingdom.any((c) =>
            c.hasTag(CardTag.trashCards) || c.hasTag(CardTag.trashForBenefit))) {
      notes.add(
        'Curse-giving Attacks present with no Trashing — consider prioritising '
        'Province timing to end the game before Curses pile up.',
      );
    }

    return notes;
  }
}
