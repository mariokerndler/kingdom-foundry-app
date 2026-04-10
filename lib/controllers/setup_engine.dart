import 'dart:math';

import '../models/card_tag.dart';
import '../models/card_type.dart';
import '../models/kingdom_card.dart';
import '../models/expansion.dart';
import '../models/setup_result.dart';
import '../models/setup_rules.dart';
import 'setup_exception.dart';

const _plunderLootNames = {
  'Amphora',
  'Doubloons',
  'Endless Chalice',
  'Figurehead',
  'Hammer',
  'Insignia',
  'Jewels',
  'Orb',
  'Prize Goat',
  'Puzzle Box',
  'Sextant',
  'Shield',
  'Spell Scroll',
  'Staff',
  'Sword',
};

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
    required List<KingdomCard> allCards,
    required Set<Expansion> ownedExpansions,
    required SetupRules rules,
  }) {
    // ── Step A ── Expansion filter ──────────────────────────────────────────
    final pool = _stepAKingdomPool(allCards, ownedExpansions);
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
    final (kingdom, locked) = _stepDSelect(pool, rules);

    // ── Step F ── Auto-reaction swap ─────────────────────────────────────────
    if (rules.requireReactionIfAttacks) {
      _stepFAutoReaction(kingdom, locked, pool);
    }

    // ── Step E ── Landscape cards ────────────────────────────────────────────
    final landscapeResult = _stepESelectLandscape(
      landscape,
      kingdom,
      ownedExpansions,
      rules,
    );

    // ── Supplement ── Setup notes ────────────────────────────────────────────
    final notes =
        _generateSetupNotes(kingdom, landscapeResult, ownedExpansions);

    return SetupResult(
      kingdomCards: kingdom,
      landscapeCards: landscapeResult,
      archetypes: const [], // populated later by HeuristicEngine
      setupNotes: notes,
      generatedAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // Step A — Pools
  // ===========================================================================

  /// Kingdom pool: owned, isKingdomCard. For split piles, one card per pile id
  /// (the lower-cost half) acts as the pile representative; the other is kept
  /// alongside so both are added to the kingdom when the pile is selected.
  List<KingdomCard> _stepAKingdomPool(
    List<KingdomCard> all,
    Set<Expansion> owned,
  ) =>
      all.where((c) => owned.contains(c.expansion) && c.isKingdomCard).toList();

  /// Landscape pool: owned, non-kingdom (Events, Landmarks, Projects, Ways, Allies).
  List<KingdomCard> _stepALandscapePool(
    List<KingdomCard> all,
    Set<Expansion> owned,
  ) =>
      all
          .where((c) => owned.contains(c.expansion) && !c.isKingdomCard)
          .toList();

  // ===========================================================================
  // Step B — Manual exclusions
  // ===========================================================================

  void _stepBRemoveDisabled(List<KingdomCard> pool) {
    pool.removeWhere((c) => c.isDisabled);
  }

  // ===========================================================================
  // Step C — Rule modifiers
  // ===========================================================================

  void _stepCApplyRules(List<KingdomCard> pool, SetupRules rules) {
    pool.removeWhere((c) {
      if (rules.noAttacks && c.isAttack) return true;
      if (rules.noDuration && c.isDuration) return true;
      if (rules.noPotions && c.potionCost) return true;
      if (rules.noDebt && c.debtCost != null) return true;
      if (rules.noCursers && c.hasTag(CardTag.curse)) return true;
      if (rules.noTravellers && c.isTraveller) return true;
      if (rules.maxCost != null && c.cost > rules.maxCost!) return true;
      return false;
    });
  }

  // ===========================================================================
  // Step D — Selection (split-pile aware)
  // ===========================================================================

  (List<KingdomCard>, List<KingdomCard>) _stepDSelect(
    List<KingdomCard> pool,
    SetupRules rules,
  ) {
    // Collapse split piles: group by splitPileId.
    // Each unique pile id becomes one "slot". Within a slot, all member cards
    // are always selected together.
    final splitGroups = <String, List<KingdomCard>>{};
    final singles = <KingdomCard>[];

    for (final c in pool) {
      if (c.splitPileId != null) {
        (splitGroups[c.splitPileId!] ??= []).add(c);
      } else {
        singles.add(c);
      }
    }

    // Build a list of "pile representatives" for shuffling.
    // Each representative is the lowest-cost card in the group.
    final pileReps = <KingdomCard>[
      ...singles,
      ...splitGroups.values.map(
        (g) => g.reduce((a, b) => a.cost <= b.cost ? a : b),
      ),
    ]..shuffle(_rng);

    final kingdom = <KingdomCard>[];
    final locked = <KingdomCard>[];

    // Track slots filled (each split pile counts as 1 slot regardless of how
    // many individual cards it adds to [kingdom]).
    var slotsSelected = 0;

    // ── Phase 1: required slots ─────────────────────────────────────────────

    void reserveSlot(
      bool condition,
      bool Function(KingdomCard) matcher,
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
      slotsSelected++;
    }

    reserveSlot(
      rules.requireVillage,
      (c) =>
          c.hasTag(CardTag.villageEffect) || c.hasTag(CardTag.plusTwoActions),
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
    reserveSlot(
      rules.requireDraw,
      (c) => c.hasTag(CardTag.plusCard) || c.hasTag(CardTag.drawToX),
      'Require Draw',
    );

    // ── Phase 2: random fill ────────────────────────────────────────────────

    int attacksInKingdom = kingdom.where((c) => c.isAttack).length;

    for (final rep in pileReps) {
      if (slotsSelected >= 10) break;
      final pileCards = _allCardsForRep(rep, splitGroups);
      final pileIsAttack = pileCards.any((c) => c.isAttack);
      if (rules.maxAttacks != null &&
          pileIsAttack &&
          attacksInKingdom >= rules.maxAttacks!) {
        continue;
      }
      _addPile(rep, splitGroups, kingdom);
      slotsSelected++;
      if (pileIsAttack) attacksInKingdom++;
    }

    if (slotsSelected < 10) {
      throw SetupException(
        'Pool exhausted before 10 slots could be selected '
        '($slotsSelected/10). This is likely a bug.',
        SetupFailureReason.poolTooSmall,
      );
    }

    // ── Phase 3: expansion variety ──────────────────────────────────────────

    // Count locked slots (each split pile = 1 slot even if it has 2 cards).
    final lockedSlots = locked.map((c) => c.splitPileId ?? c.id).toSet().length;

    if (rules.minExpansionVariety > 1) {
      final ownedCount = pool.map((c) => c.expansion).toSet().length;
      _enforceExpansionVariety(
        kingdom: kingdom,
        locked: locked,
        remainder: pileReps.skip(10 - lockedSlots).toList(),
        splitGroups: splitGroups,
        minVariety: rules.minExpansionVariety,
        ownedCount: ownedCount,
      );
    }

    _enforceAlchemyCluster(
      kingdom: kingdom,
      locked: locked,
      candidates: pileReps,
      splitGroups: splitGroups,
    );

    // Sort by cost (ascending) for natural display order.
    kingdom.sort((a, b) {
      final cmp = a.cost.compareTo(b.cost);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    return (kingdom, locked);
  }

  /// Adds a pile representative (and all its split-pile partners) to [kingdom].
  void _addPile(
    KingdomCard rep,
    Map<String, List<KingdomCard>> splitGroups,
    List<KingdomCard> kingdom,
  ) {
    kingdom.addAll(_allCardsForRep(rep, splitGroups));
  }

  /// Returns all cards that belong to the same pile as [rep].
  List<KingdomCard> _allCardsForRep(
    KingdomCard rep,
    Map<String, List<KingdomCard>> splitGroups,
  ) {
    if (rep.splitPileId != null) {
      return splitGroups[rep.splitPileId!] ?? [rep];
    }
    return [rep];
  }

  /// Effective pool size = number of kingdom slots (each split pile = 1 slot).
  int _effectivePoolSize(List<KingdomCard> pool) {
    final splitIds = pool
        .where((c) => c.splitPileId != null)
        .map((c) => c.splitPileId!)
        .toSet();
    final singleCount = pool.where((c) => c.splitPileId == null).length;
    return singleCount + splitIds.length;
  }

  /// Alchemy is designed to appear in clusters: a single Potion-cost card often
  /// asks players to buy Potions for too little payoff. When a mixed kingdom
  /// already includes Alchemy, gently steer it toward 3-5 Alchemy slots.
  void _enforceAlchemyCluster({
    required List<KingdomCard> kingdom,
    required List<KingdomCard> locked,
    required List<KingdomCard> candidates,
    required Map<String, List<KingdomCard>> splitGroups,
  }) {
    final kingdomExpansions = kingdom.map((c) => c.expansion).toSet();
    if (!kingdomExpansions.contains(Expansion.alchemy)) return;

    // If Alchemy is the only selected expansion, there is nothing sensible to
    // swap against; all-Alchemy games are allowed.
    if (kingdomExpansions.length == 1) return;

    final lockedSlots = locked.map(_slotId).toSet();

    int alchemySlots() => kingdom
        .where((c) => c.expansion == Expansion.alchemy)
        .map(_slotId)
        .toSet()
        .length;

    final candidatePool = candidates
        .where((c) => !kingdom.any((k) => _slotId(k) == _slotId(c)))
        .toList()
      ..shuffle(_rng);

    while (alchemySlots() < 3) {
      final incoming = candidatePool.cast<KingdomCard?>().firstWhere(
            (c) => c!.expansion == Expansion.alchemy,
            orElse: () => null,
          );
      if (incoming == null) break;

      final outgoing = kingdom.cast<KingdomCard?>().firstWhere(
            (c) =>
                c!.expansion != Expansion.alchemy &&
                !lockedSlots.contains(_slotId(c)),
            orElse: () => null,
          );
      if (outgoing == null) break;

      _replacePile(
        outgoing: outgoing,
        incoming: incoming,
        splitGroups: splitGroups,
        kingdom: kingdom,
      );
      candidatePool.remove(incoming);
    }

    while (alchemySlots() > 5) {
      final incoming = candidatePool.cast<KingdomCard?>().firstWhere(
            (c) => c!.expansion != Expansion.alchemy,
            orElse: () => null,
          );
      if (incoming == null) break;

      final outgoing = kingdom.cast<KingdomCard?>().firstWhere(
            (c) =>
                c!.expansion == Expansion.alchemy &&
                !lockedSlots.contains(_slotId(c)),
            orElse: () => null,
          );
      if (outgoing == null) break;

      _replacePile(
        outgoing: outgoing,
        incoming: incoming,
        splitGroups: splitGroups,
        kingdom: kingdom,
      );
      candidatePool.remove(incoming);
    }
  }

  void _replacePile({
    required KingdomCard outgoing,
    required KingdomCard incoming,
    required Map<String, List<KingdomCard>> splitGroups,
    required List<KingdomCard> kingdom,
  }) {
    final outgoingSlot = _slotId(outgoing);
    kingdom.removeWhere((c) => _slotId(c) == outgoingSlot);
    _addPile(incoming, splitGroups, kingdom);
  }

  String _slotId(KingdomCard card) => card.splitPileId ?? card.id;

  // ===========================================================================
  // Step F — Auto-reaction swap
  // ===========================================================================

  /// If the kingdom has Attacks but no Reactions, swaps one non-locked,
  /// non-Attack card for a random Reaction from the filtered pool.
  void _stepFAutoReaction(
    List<KingdomCard> kingdom,
    List<KingdomCard> locked,
    List<KingdomCard> filteredPool,
  ) {
    if (!kingdom.any((c) => c.isAttack)) return;
    if (kingdom.any((c) => c.isReaction)) return;

    final kingdomIds = kingdom.map((c) => c.id).toSet();
    final reactions = filteredPool
        .where((c) => c.isReaction && !kingdomIds.contains(c.id))
        .toList()
      ..shuffle(_rng);

    if (reactions.isEmpty) return;

    final lockedIds = locked.map((c) => c.id).toSet();
    final alchemySlots = kingdom
        .where((c) => c.expansion == Expansion.alchemy)
        .map(_slotId)
        .toSet()
        .length;
    final swappable = kingdom
        .where((c) => !lockedIds.contains(c.id) && !c.isAttack)
        .toList()
      ..shuffle(_rng);
    final preferredSwappable = alchemySlots <= 3
        ? swappable.where((c) => c.expansion != Expansion.alchemy).toList()
        : swappable;

    if (preferredSwappable.isEmpty) return;

    kingdom.remove(preferredSwappable.first);
    kingdom.add(reactions.first);
  }

  // ===========================================================================
  // Step E — Landscape cards
  // ===========================================================================

  /// Draws landscape cards according to per-type counts in [rules].
  List<KingdomCard> _stepESelectLandscape(
    List<KingdomCard> pool,
    List<KingdomCard> kingdom,
    Set<Expansion> owned,
    SetupRules rules,
  ) {
    if (pool.isEmpty) return const [];

    final result = <KingdomCard>[];
    final shuffled = [...pool]..shuffle(_rng);

    void draw(bool Function(KingdomCard) filter, int count) {
      if (count <= 0) return;
      final candidates = shuffled.where(filter).toList();
      result.addAll(candidates.take(count.clamp(0, candidates.length)));
    }

    if (rules.includeLandscape) {
      draw((c) => c.isEvent, rules.landscapeEvents);
      draw((c) => c.isLandmark, rules.landscapeLandmarks);
      draw((c) => c.isProject, rules.landscapeProjects);
      draw((c) => c.isWay, rules.landscapeWays);
      draw((c) => c.isTrait, rules.landscapeTraits);
    }

    if (kingdom.any((c) => c.isOmen)) {
      result.removeWhere((c) => c.isProphecy);
      final prophecies = shuffled.where((c) => c.isProphecy).toList();
      if (prophecies.isNotEmpty) result.add(prophecies.first);
    }

    // Allies are not optional landscapes when Liaisons are present: a game with
    // one or more Liaisons uses exactly one Ally, separate from other landscapes.
    if (kingdom.any((c) => c.isLiaison)) {
      result.removeWhere((c) => c.isAlly);
      final allies = shuffled.where((c) => c.isAlly).toList();
      if (allies.isNotEmpty) result.add(allies.first);
    }

    return result;
  }

  // ===========================================================================
  // Expansion variety enforcement
  // ===========================================================================

  void _enforceExpansionVariety({
    required List<KingdomCard> kingdom,
    required List<KingdomCard> locked,
    required List<KingdomCard> remainder,
    required Map<String, List<KingdomCard>> splitGroups,
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

      final candidate = remainder.cast<KingdomCard?>().firstWhere(
            (c) => !present.contains(c!.expansion),
            orElse: () => null,
          );
      if (candidate == null) break;

      final overExp = _mostRepresentedExpansion(kingdom, locked);
      final evictPool = swappable.where((c) => c.expansion == overExp).toList();
      final evict = evictPool.isNotEmpty
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
    List<KingdomCard> kingdom,
    List<KingdomCard> locked,
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
    List<KingdomCard> kingdom,
    List<KingdomCard> landscape,
    Set<Expansion> owned,
  ) {
    final notes = <String>[];
    final kingdomExp = kingdom.map((c) => c.expansion).toSet();
    final allPresent = {...kingdomExp, ...landscape.map((c) => c.expansion)};
    final setupCards = [...kingdom, ...landscape];

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
      notes.add(
        'Potion-cost cards present: add the Potion Supply pile. Use all 16 '
        'Potions; each costs \$4, produces 1 Potion when played, and counts '
        'as a Supply pile if emptied.',
      );
    }

    // Empires / debt cards
    if (setupCards.any((c) => c.debtCost != null || c.hasTag(CardTag.debt))) {
      notes.add(
        'Debt cards present: prepare the Debt token supply '
        '(the coin-shaped cardboard tokens).',
      );
    }

    if (setupCards.any((c) => c.hasTag(CardTag.coffers))) {
      notes.add(
        'Coffers present: prepare Coin tokens and Coffers mats. '
        'Each player starts with 0 Coffers unless Baker is present.',
      );
    }

    if (setupCards.any((c) => c.hasTag(CardTag.villagers))) {
      notes.add(
        'Villagers present: prepare Villager mats and tokens. Each player '
        'starts with 0 Villagers.',
      );
    }

    if (kingdom.any((c) => c.name == 'Baker')) {
      notes.add(
        'Baker present: each player starts with 1 Coffers on their mat.',
      );
    }

    if (kingdom.any((c) => c.name == 'Footpad')) {
      notes.add(
        'Footpad present: for the whole game, whenever a player gains a card '
        'during an Action phase, that player draws a card.',
      );
    }

    if (kingdom.any((c) => c.name == 'Ferryman')) {
      notes.add(
        'Ferryman present: choose an unused Kingdom pile costing \$3 or \$4 '
        'and set it near the Supply; gaining Ferryman also gains one of those cards.',
      );
    }

    if (kingdom.any((c) => c.name == 'Joust')) {
      notes.add(
        'Joust present: set out the Rewards. Use one of each for 2 players, '
        'or two of each for 3-6 players.',
      );
    }

    final plunderCards = setupCards
        .where((c) => c.expansion == Expansion.plunder)
        .toList(growable: false);
    final usesLootPile = plunderCards.any((c) =>
        c.isLoot ||
        c.pileCards.any((pileCard) => _plunderLootNames.contains(pileCard)));
    if (usesLootPile) {
      notes.add(
        'Loot pile present: set aside two copies of each Loot and shuffle '
        'them face down. When a Loot is gained, reveal the top card; if the '
        'pile is empty, shuffle discarded Loot to make a new pile.',
      );
    }

    if (landscape.any((c) => c.isTrait)) {
      notes.add(
        'Trait setup: assign each Trait to a random Action/Treasure Kingdom '
        'pile, with no pile receiving more than one Trait. On split piles, '
        'the Trait applies to every card in that pile.',
      );
    }

    if (kingdom.any((c) => c.isShadow)) {
      notes.add(
        'Shadow cards present: when shuffling Shadow cards, put them on the '
        'bottom of your deck. You may play Shadow cards from your deck as if '
        'they were in your hand whenever you could normally play an Action.',
      );
    }

    final selectedProphecy = landscape.cast<KingdomCard?>().firstWhere(
          (c) => c!.isProphecy,
          orElse: () => null,
        );
    if (selectedProphecy != null) {
      notes.add(
        'Prophecy present (${selectedProphecy.name}): use one Prophecy for the '
        'game and put Sun tokens on it based on player count '
        '(5 for 2p, 8 for 3p, 10 for 4p, 12 for 5p, 13 for 6p). '
        'Each +1 Sun removes one token; when the last token is removed, the '
        'Prophecy text becomes active for the rest of the game.',
      );
      if (selectedProphecy.name == 'Approaching Army') {
        notes.add(
          'Approaching Army setup: add an unused Attack Kingdom pile to the '
          'Supply, in addition to the normal 10 Kingdom piles.',
        );
      }
    }

    if (kingdom.any((c) => c.name == 'Riverboat')) {
      notes.add(
        'Riverboat present: set aside an unused non-Duration Action card '
        'costing exactly \$5 before play; Riverboat will play that card at the '
        'start of your next turn, leaving it set aside.',
      );
    }

    if (kingdom.any((c) => c.name == 'Young Witch')) {
      notes.add(
        'Young Witch present: add an extra Kingdom pile costing \$2 or \$3 '
        'to the Supply as the Bane pile.',
      );
    }

    final adventureCards = [
      ...kingdom.where((c) => c.expansion == Expansion.adventures),
      ...landscape.where((c) => c.expansion == Expansion.adventures),
    ];
    if (adventureCards.any((c) => c.types.contains(CardType.reserve))) {
      notes.add(
        'Reserve cards present: each player needs a Tavern mat for called '
        'and set-aside Reserve cards.',
      );
    }

    if (kingdom.any((c) => c.name == 'Port')) {
      notes.add('Port present: use all 12 Ports in its Supply pile.');
    }

    if (adventureCards.any((c) =>
        c.name == 'Ranger' || c.name == 'Giant' || c.name == 'Pilgrimage')) {
      notes.add(
        'Journey token present: each player starts with their Journey token '
        'face up.',
      );
    }

    if (adventureCards.any((c) => c.hasTag(CardTag.tokens))) {
      notes.add(
        'Adventures tokens present: prepare the player tokens used by this '
        'set, such as -1 Card, -\$1, -\$2 cost, Estate, Trashing, +1 Card, '
        '+1 Action, +1 Buy, and +\$1 tokens as needed.',
      );
    }

    final renaissanceCards = setupCards
        .where((c) => c.expansion == Expansion.renaissance)
        .toList(growable: false);
    if (renaissanceCards.any((c) => c.isProject)) {
      notes.add(
        'Projects present: set out Project cards with player cubes; each '
        'player marks Projects they buy with one of their cubes.',
      );
    }

    final artifacts = <String>{
      if (kingdom.any((c) => c.name == 'Flag Bearer')) 'Flag',
      if (kingdom.any((c) => c.name == 'Border Guard')) 'Lantern/Horn',
      if (kingdom.any((c) => c.name == 'Treasurer')) 'Key',
      if (kingdom.any((c) => c.name == 'Swashbuckler')) 'Treasure Chest',
    };
    if (artifacts.isNotEmpty) {
      notes.add(
        'Artifacts present: set aside ${artifacts.join(', ')}. These move to '
        'the player currently holding them.',
      );
    }

    final menagerieCards = setupCards
        .where((c) => c.expansion == Expansion.menagerie)
        .toList(growable: false);
    if (menagerieCards.any((c) => c.hasTag(CardTag.exile))) {
      notes.add(
        'Exile effects present: each player needs an Exile mat. When gaining '
        'a card, players may discard matching cards from their Exile mat.',
      );
    }

    if (menagerieCards.any((c) =>
        c.pileCards.contains('Horse') ||
        c.name == 'Way of the Horse' ||
        c.name == 'Ride')) {
      notes.add(
        'Horse gainers present: set aside the Horse pile; Horses are not in '
        'the Supply and return to their pile when played.',
      );
    }

    if (landscape.any((c) => c.name == 'Way of the Mouse')) {
      notes.add(
        'Way of the Mouse present: set aside an unused non-Duration Action '
        'card costing \$2 or \$3 before play.',
      );
    }

    final empiresCards = setupCards
        .where((c) => c.expansion == Expansion.empires)
        .toList(growable: false);
    if (empiresCards.any((c) => c.hasTag(CardTag.pointTokens))) {
      notes.add(
        'Empires VP tokens present: prepare the Victory Point token supply.',
      );
    }

    if (kingdom.any((c) => c.name == 'Castles')) {
      notes.add(
        'Castles present: sort the Castle pile by cost with Humble Castle on '
        'top and King\'s Castle on the bottom. Use one of each Castle for '
        '2 players, or all 12 Castle cards with more players.',
      );
    }

    if (kingdom.any((c) => c.types.contains(CardType.gathering))) {
      notes.add(
        'Gathering pile present: VP tokens on Farmers\' Market, Temple, or '
        'Wild Hunt stay on their Supply pile until a card effect removes them.',
      );
    }

    if (landscape.any((c) =>
        c.expansion == Expansion.empires && c.hasTag(CardTag.pointTokens))) {
      notes.add(
        'Empires Landmark VP tokens: follow each Landmark\'s setup text for '
        'placing VP tokens before play.',
      );
    }

    // Dark Ages: Shelters
    if (kingdomExp.contains(Expansion.darkAges)) {
      notes.add(
        'Dark Ages present: optionally start with Shelters '
        '(Hovel, Necropolis, Overgrown Estate) instead of starting Estates.',
      );
    }

    if (kingdom.any((c) => c.isLooter)) {
      notes.add(
        'Looter present: prepare and shuffle the Ruins pile '
        '(10 Ruins per player after the first), with the top card face up.',
      );
    }

    if (kingdom.any((c) => c.name == 'Knights')) {
      notes.add(
        'Knights present: shuffle the 10 Knights into one Supply pile and '
        'place the top Knight face up.',
      );
    }

    final specialPiles = <String>{
      if (kingdom.any((c) =>
          c.name == 'Bandit Camp' ||
          c.name == 'Marauder' ||
          c.name == 'Pillage'))
        'Spoils',
      if (kingdom.any((c) => c.name == 'Hermit')) 'Madman',
      if (kingdom.any((c) => c.name == 'Urchin')) 'Mercenary',
    };
    if (specialPiles.isNotEmpty) {
      notes.add(
        'Dark Ages non-Supply pile${specialPiles.length == 1 ? '' : 's'}: '
        'set aside ${specialPiles.join(', ')}.',
      );
    }

    final nocturneCards = kingdom
        .where((c) => c.expansion == Expansion.nocturne)
        .toList(growable: false);
    if (nocturneCards.isNotEmpty) {
      notes.add(
        'Nocturne present: play an Action phase, then Buy phase, then Night '
        'phase each turn.',
      );
    }

    final heirloomPairs = <String, String>{
      'Cemetery': 'Haunted Mirror',
      'Fool': 'Lucky Coin',
      'Pixie': 'Goat',
      'Pooka': 'Cursed Gold',
      'Secret Cave': 'Magic Lamp',
      'Shepherd': 'Pasture',
      'Tracker': 'Pouch',
    };
    final activeHeirlooms = heirloomPairs.entries
        .where((entry) => kingdom.any((c) => c.name == entry.key))
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList(growable: false);
    if (activeHeirlooms.isNotEmpty) {
      notes.add(
        'Nocturne Heirlooms: replace one starting Copper for each matching '
        'Kingdom card (${activeHeirlooms.join(', ')}).',
      );
    }

    if (nocturneCards.any((c) => c.types.contains(CardType.fate))) {
      notes.add(
        'Fate cards present: shuffle the Boon deck and set out the '
        'Will-o\'-Wisp pile.',
      );
    }

    if (kingdom.any((c) => c.name == 'Druid')) {
      notes.add(
        'Druid present: set aside the top 3 Boons face up; Druid chooses '
        'from those instead of the Boon deck.',
      );
    }

    if (nocturneCards.any((c) => c.types.contains(CardType.doom))) {
      notes.add(
        'Doom cards present: shuffle the Hex deck and set out the State cards '
        '(Deluded/Envious, Miserable/Twice Miserable).',
      );
    }

    final nocturnePiles = <String>{
      if (kingdom.any((c) => c.name == 'Necromancer'))
        'the 3 Zombies in the trash',
      if (kingdom.any((c) => c.name == 'Exorcist')) 'Spirit piles',
      if (kingdom.any((c) => c.name == 'Vampire')) 'Bat pile',
      if (kingdom.any((c) => c.name == 'Fool')) 'Lost in the Woods State',
      if (kingdom.any((c) => c.name == 'Leprechaun' || c.name == 'Secret Cave'))
        'Wish pile',
      if (kingdom
          .any((c) => c.name == 'Devil\'s Workshop' || c.name == 'Tormentor'))
        'Imp pile',
      if (kingdom.any((c) => c.name == 'Cemetery')) 'Ghost pile',
    };
    if (nocturnePiles.isNotEmpty) {
      notes.add(
        'Nocturne non-Supply cards: set aside ${nocturnePiles.join(', ')}.',
      );
    }

    // Traveller/exchange chains
    for (final c in kingdom.where((c) => c.isTraveller)) {
      final chain = c.travellerChain.join(' → ');
      notes.add(
        '${c.name} has an exchange chain: have the set-aside card(s) available '
        '($chain) and set those cards aside before play.',
      );
    }

    // Allies / Favors
    if (kingdom.any((c) => c.isLiaison)) {
      final allyNames = landscape.where((c) => c.isAlly).map((c) => c.name);
      final startingFavors = kingdom.any((c) => c.name == 'Importer') ? 5 : 1;
      notes.add(
        'Liaison setup: set out ${allyNames.isEmpty ? 'one Ally' : allyNames.join(' / ')}, '
        'give each player a Favors mat, and start each player with '
        '$startingFavors Favor token${startingFavors == 1 ? '' : 's'}.',
      );
    }

    // Split piles — remind players to set the shared pile out
    final splitIds =
        kingdom.where((c) => c.isSplitPile).map((c) => c.splitPileId!).toSet();
    for (final id in splitIds) {
      final pile = kingdom.where((c) => c.splitPileId == id).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));
      if (pile.length > 2) {
        notes.add(
          'Rotating pile: ${pile.map((c) => c.name).join(' / ')} — place all '
          'cards in one Supply pile in cost order with ${pile.first.name} on top, '
          'and rotate it when instructed.',
        );
      } else if (pile.length == 2) {
        notes.add(
          'Split pile: ${pile.map((c) => c.name).join(' / ')} — place both '
          'halves in a single Supply pile, lower-cost (${pile.first.name}) on top.',
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
            c.hasTag(CardTag.trashCards) ||
            c.hasTag(CardTag.trashForBenefit))) {
      notes.add(
        'Curse-giving Attacks present with no Trashing — consider prioritising '
        'Province timing to end the game before Curses pile up.',
      );
    }

    return notes;
  }
}
