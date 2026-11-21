import 'dart:math';

import '../models/card_tag.dart';
import '../models/card_metadata.dart';
import '../models/cost_curve_rule.dart';
import '../models/card_type.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/expansion.dart';
import '../models/setup_result.dart';
import '../models/setup_rules.dart';
import 'setup_exception.dart';

typedef PileReplacement = ({
  List<KingdomCard> cards,
  List<KingdomCard> landscapes,
  Map<String, String> setupChoices,
  List<String> setupNotes,
});

const _druidBoonSlots = ['druid_boon_1', 'druid_boon_2', 'druid_boon_3'];

const _plunderLootIds = {
  'amphora',
  'doubloons',
  'endless_chalice',
  'figurehead',
  'hammer',
  'insignia',
  'jewels',
  'orb',
  'prize_goat',
  'puzzle_box',
  'sextant',
  'shield',
  'spell_scroll',
  'staff',
  'sword',
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
  static const int _costCurveSearchBudget = 100;
  static const int _presetSearchBudget = 60;
  final Random _rng;

  SetupEngine({Random? random}) : _rng = random ?? Random();

  // ===========================================================================
  // Public API
  // ===========================================================================

  SetupResult generate({
    required List<KingdomCard> allCards,
    required Set<Expansion> ownedExpansions,
    required SetupRules rules,
    GameVibePreset? preset,
    Set<String> excludedCardIds = const {},
    List<KingdomCard> lockedKingdomCards = const [],
    List<KingdomCard> lockedLandscapeCards = const [],
    Map<String, String> previousSetupChoices = const {},
    Set<String> recentSlots = const {},
  }) {
    // ── Step A ── Expansion filter ──────────────────────────────────────────
    final pool = eligibleKingdomPool(allCards, ownedExpansions, rules,
        excludedCardIds: excludedCardIds);
    final landscape = _stepALandscapePool(allCards, ownedExpansions, rules);

    // ── Step B ── Manual exclusions ─────────────────────────────────────────
    landscape.removeWhere((card) => excludedCardIds.contains(card.id));

    // ── Step C ── Global rule modifiers ─────────────────────────────────────
    final poolIds = pool.map((card) => card.id).toSet();
    if (lockedKingdomCards.any((card) => !poolIds.contains(card.id))) {
      throw const SetupException(
          'A locked pile conflicts with your expansions, bans, or rules. Unlock it or adjust the filters.',
          SetupFailureReason.requirementImpossible);
    }
    final lockedSlots = lockedKingdomCards.map(_slotId).toSet();
    lockedKingdomCards =
        pool.where((card) => lockedSlots.contains(_slotId(card))).toList();
    if (lockedSlots.length > 10) {
      throw const SetupException('At most 10 kingdom piles can be locked.',
          SetupFailureReason.requirementImpossible);
    }

    final conflict = poolConflict(pool, rules);
    if (conflict != null) throw conflict;

    // ── Step D/F ── Kingdom selection and post-processing ───────────────────
    final kingdom = _selectKingdomForRules(
      pool,
      rules,
      preset: preset,
      lockedKingdomCards: lockedKingdomCards,
      recentSlots: recentSlots,
    );

    // ── Step E ── Landscape cards ────────────────────────────────────────────
    final landscapeResult = _stepESelectLandscape(
      landscape,
      rules,
      lockedLandscapeCards: lockedLandscapeCards,
    );

    // ── Supplement ── Setup notes ────────────────────────────────────────────
    final table = completeTableSetup(
      SetupResult(
          kingdomCards: kingdom,
          landscapeCards: landscapeResult,
          archetypes: const [],
          setupNotes: const [],
          generatedAt: DateTime.now()),
      pool,
      previous: previousSetupChoices,
      rules: rules,
      excludedCardIds: excludedCardIds,
      landscapePool: landscape,
      catalogue: allCards,
    );
    final notes = [...table.setupNotes];
    final rationale = _generateSelectionRationale(
      kingdom: kingdom,
      rules: rules,
      preset: preset,
    );
    if (recentSlots.isNotEmpty) {
      final reused =
          kingdom.map(_slotId).toSet().intersection(recentSlots).length;
      rationale.add('$reused of 10 piles appeared in the last three boards.');
    }
    if (rules.costCurve.enabled && rules.costCurve.isValid) {
      final actual = _costBucketCounts(kingdom);
      notes.add(
        'Cost curve target ${CostCurveRule.describeBucketCounts(rules.costCurve.bucketCounts)}; '
        'actual ${CostCurveRule.describeBucketCounts(actual)}; '
        'matched ${_matchedCurveSlots(rules.costCurve, actual)}/${CostCurveRule.targetSlotCount} slots.',
      );
    }

    return table.copyWith(
      setupNotes: notes,
      selectionRationale: rationale,
      presetId: preset?.id,
      lockedSlotIds: lockedKingdomCards.map(_slotId).toSet(),
      lockedLandscapeIds: lockedLandscapeCards.map((card) => card.id).toSet(),
    );
  }

  SetupResult completeTableSetup(
    SetupResult result,
    List<KingdomCard> eligible, {
    Map<String, String> previous = const {},
    bool validatePrevious = false,
    List<KingdomCard> landscapePool = const [],
    bool keepRequiredLandscapes = true,
    List<KingdomCard> catalogue = const [],
    SetupRules rules = const SetupRules(),
    Set<String> excludedCardIds = const {},
  }) {
    const prefix = 'black_market:';
    final all = catalogue.isEmpty ? eligible : catalogue;
    final byId = {for (final card in all) card.id: card};
    final pool = <String, ({KingdomCard card, String pile})>{};
    for (final card in eligible.where((card) => card.isKingdomCard)) {
      final members = card.id == 'knights' || card.id == 'castles'
          ? card.pileCardIds
              .map((id) => byId[id])
              .whereType<KingdomCard>()
              .toList()
          : [card];
      _stepCApplyRules(members, rules);
      for (final member in members) {
        if (member.id == 'black_market' ||
            excludedCardIds.contains(member.id)) {
          continue;
        }
        if (member.isLiaison &&
            ![...landscapePool, ...result.landscapeCards]
                .any((c) => c.isAlly)) {
          continue;
        }
        if (member.isOmen &&
            ![...landscapePool, ...result.landscapeCards]
                .any((c) => c.isProphecy)) {
          continue;
        }
        pool[member.id] = (card: member, pile: card.pileId);
      }
    }
    final saved = previous.entries
        .where((entry) => entry.key.startsWith(prefix))
        .toList()
      ..sort((a, b) => (int.tryParse(a.key.substring(prefix.length)) ?? -1)
          .compareTo(int.tryParse(b.key.substring(prefix.length)) ?? -1));
    if (validatePrevious &&
        (saved.asMap().entries.any((entry) =>
                entry.value.key != '$prefix${entry.key + 1}' ||
                !pool.containsKey(entry.value.value)) ||
            saved.map((entry) => pool[entry.value]?.pile).toSet().length !=
                saved.length)) {
      throw const FormatException('Invalid Black Market deck choices.');
    }
    var deck = [
      for (final entry in saved)
        if (pool[entry.value] case final candidate?) candidate.card
    ];
    var choices = {
      for (final entry in previous.entries)
        if (!entry.key.startsWith(prefix)) entry.key: entry.value
    };
    final seen = deck.map((card) => pool[card.id]!.pile).toSet();
    final requested = validatePrevious && saved.isNotEmpty
        ? saved.length
        : max(15, deck.length);
    for (var attempt = 0; attempt <= pool.length + 1; attempt++) {
      final table = _completeTableSetup(result, eligible,
          previous: choices,
          validatePrevious: validatePrevious,
          landscapePool: landscapePool,
          keepRequiredLandscapes: keepRequiredLandscapes,
          catalogue: catalogue,
          blackMarketDeck: deck);
      final present = [
        ...table.kingdomCards,
        for (final id in table.setupChoices.values)
          if (byId[id] case final card?) card
      ];
      if (!present.any((card) => card.id == 'black_market')) {
        if (validatePrevious && saved.isNotEmpty) {
          throw const FormatException(
              'Black Market deck has no Black Market source.');
        }
        if (deck.isNotEmpty) {
          deck = [];
          choices = table.setupChoices;
          continue;
        }
        return table;
      }
      final used =
          present.map((card) => pool[card.id]?.pile ?? card.pileId).toSet();
      final next = <KingdomCard>[];
      final selected = <String>{};
      for (final card in deck) {
        final pile = pool[card.id]!.pile;
        if (!used.contains(pile) && selected.add(pile)) next.add(card);
      }
      if (validatePrevious && saved.isNotEmpty && next.length != saved.length) {
        throw const FormatException(
            'Black Market cards overlap other setup cards.');
      }
      final byPile = <String, List<KingdomCard>>{};
      for (final candidate in pool.values) {
        (byPile[candidate.pile] ??= []).add(candidate.card);
      }
      final available = byPile.entries.toList()..shuffle(_rng);
      for (final candidate in available) {
        if (next.length >= requested) break;
        if (!used.contains(candidate.key) &&
            !seen.contains(candidate.key) &&
            selected.add(candidate.key)) {
          next.add(candidate.value[_rng.nextInt(candidate.value.length)]);
          seen.add(candidate.key);
        }
      }
      if (next.length == deck.length && next.every(deck.contains)) {
        return table.copyWith(
            setupChoices: Map.unmodifiable({
          ...table.setupChoices,
          for (var i = 0; i < deck.length; i++) '$prefix${i + 1}': deck[i].id,
        }));
      }
      deck = next;
      choices = table.setupChoices;
    }
    throw const SetupException('Could not resolve the Black Market deck setup.',
        SetupFailureReason.requirementImpossible);
  }

  SetupResult _completeTableSetup(
    SetupResult result,
    List<KingdomCard> eligible, {
    Map<String, String> previous = const {},
    bool validatePrevious = false,
    List<KingdomCard> landscapePool = const [],
    bool keepRequiredLandscapes = true,
    List<KingdomCard> catalogue = const [],
    List<KingdomCard> blackMarketDeck = const [],
  }) {
    const invalidSetupChoice =
        'The shared setup contains an unavailable or incompatible setup choice.';
    final kingdom = result.kingdomCards;
    final landscape = result.landscapeCards
        .where((card) => !card.isAlly && !card.isProphecy)
        .toList();
    final groups = <String, List<KingdomCard>>{};
    for (final card in eligible.where((card) => card.isKingdomCard)) {
      (groups[_slotId(card)] ??= []).add(card);
    }
    bool coinCost(KingdomCard card, int low, int high) =>
        card.cost >= low &&
        card.cost <= high &&
        !card.potionCost &&
        card.debtCost == null;
    bool maySetAside(KingdomCard card) => card.isAction && !card.isDuration;
    KingdomCard topCard(List<KingdomCard> cards) =>
        cards.reduce((top, card) => card.cost < top.cost ? card : top);
    final extras = <String,
        ({bool pile, bool supply, bool Function(KingdomCard) matches})>{
      'young_witch': (
        pile: true,
        supply: true,
        matches: (card) => coinCost(card, 2, 3)
      ),
      'ferryman': (
        pile: true,
        supply: false,
        matches: (card) => coinCost(card, 3, 4)
      ),
      'approaching_army': (
        pile: true,
        supply: true,
        matches: (card) => card.isAttack
      ),
      'riverboat': (
        pile: false,
        supply: false,
        matches: (card) => maySetAside(card) && coinCost(card, 5, 5)
      ),
      'way_of_the_mouse': (
        pile: false,
        supply: false,
        matches: (card) => maySetAside(card) && coinCost(card, 2, 3)
      ),
    };
    const requiredTypes = {
      ':prophecy': CardType.prophecy,
      ':ally': CardType.ally,
    };
    Iterable<String> sourcesFor(Iterable<KingdomCard> cards) sync* {
      for (final card in cards) {
        if (extras.containsKey(card.id)) yield card.id;
        if (card.isLiaison) yield ':ally';
        if (card.isOmen) yield ':prophecy';
      }
    }

    Never conflict(String message) {
      if (validatePrevious) throw FormatException(message);
      throw SetupException(message, SetupFailureReason.requirementImpossible);
    }

    final kept = <String, KingdomCard>{};
    final fixed = <String, KingdomCard>{};
    final initialSources =
        sourcesFor([...kingdom, ...landscape, ...blackMarketDeck]).toSet();
    for (final entry in requiredTypes.entries) {
      final existing = result.landscapeCards
          .where((card) => card.types.contains(entry.value))
          .toList();
      if (existing.length > 1) {
        conflict('A game uses at most one ${entry.value.displayName}.');
      }
      if (existing.isEmpty) continue;
      final card = existing.single;
      kept[entry.key] = card;
      if (keepRequiredLandscapes || result.isLandscapeLocked(card.id)) {
        fixed[entry.key] = card;
      }
    }
    final kingdomSlots = result.kingdomSlotIds;
    final usedSlots = {...kingdomSlots};
    final targets = <String, KingdomCard>{};
    final additional = <KingdomCard>[];
    final supply = [...kingdom];
    List<KingdomCard> selectedCards(String source, KingdomCard card) =>
        extras[source]?.pile == true ? groups[_slotId(card)]! : [card];
    final candidates = <String, List<KingdomCard>>{};
    final retained = <String, KingdomCard>{};
    List<KingdomCard> options(String source) =>
        candidates.putIfAbsent(source, () {
          if (requiredTypes[source] case final type?) {
            final existing = kept[source];
            if (fixed.containsKey(source)) return [existing!];
            final pool = landscapePool
                .where((card) =>
                    card.types.contains(type) && card.id != existing?.id)
                .toList()
              ..shuffle(_rng);
            return [if (existing != null) existing, ...pool];
          }
          final extra = extras[source]!;
          final available = [
            for (final entry in groups.entries)
              if (!kingdomSlots.contains(entry.key))
                if (extra.pile) topCard(entry.value) else ...entry.value,
          ].where(extra.matches).toList()
            ..shuffle(_rng);
          final saved = available
              .where((card) => card.id == previous[source])
              .firstOrNull;
          if (saved != null) {
            retained[source] = saved;
            available.remove(saved);
            available.insert(0, saved);
          }
          return available;
        });

    for (final entry in requiredTypes.entries) {
      if (initialSources.contains(entry.key) && options(entry.key).isEmpty) {
        conflict(
            'This kingdom requires an available ${entry.value.displayName}. '
            'Adjust your bans or expansions.');
      }
    }
    if (fixed.keys.any((source) => !initialSources.contains(source))) {
      final reachable = initialSources.toList();
      for (var index = 0; index < reachable.length; index++) {
        final source = reachable[index];
        for (final card in options(source)) {
          for (final nested in sourcesFor(selectedCards(source, card))) {
            if (!reachable.contains(nested)) reachable.add(nested);
          }
        }
      }
      if (fixed.keys.any((source) => !reachable.contains(source))) {
        conflict('The selected Ally or Prophecy conflicts with this kingdom. '
            'Check the required card type or unlock the landscape.');
      }
    }

    if (validatePrevious) {
      final reachable = initialSources.toList();
      final reservedSlots = <String>{};
      for (var index = 0; index < reachable.length; index++) {
        final source = reachable[index];
        var saved = fixed[source];
        if (previous.containsKey(source) && extras.containsKey(source)) {
          options(source);
          saved = retained[source];
          if (saved == null || !reservedSlots.add(_slotId(saved))) {
            throw const FormatException(invalidSetupChoice);
          }
        }
        if (saved == null) continue;
        for (final nested in sourcesFor(selectedCards(source, saved))) {
          if (!reachable.contains(nested)) reachable.add(nested);
        }
      }
      if (previous.keys.any((source) =>
          extras.containsKey(source) && !reachable.contains(source))) {
        throw const FormatException(invalidSetupChoice);
      }
    }

    // Choose the most constrained effect first. Backtrack when an extra pile
    // introduces a setup requirement that would compete for the same pile.
    final resolved = <String>{};
    bool assign(Set<String> pending, int manualLeft,
        {required bool keepPrevious}) {
      if (pending.isEmpty) return fixed.keys.every(targets.containsKey);
      final available = <String, List<KingdomCard>>{};
      for (final source in pending) {
        final choices = options(source);
        final saved = retained[source];
        available[source] = (keepPrevious && saved != null ? [saved] : choices)
            .where((card) => !usedSlots.contains(_slotId(card)))
            .toList();
      }
      final source = pending.reduce(
          (a, b) => available[a]!.length <= available[b]!.length ? a : b);
      final remaining = {...pending}..remove(source);
      resolved.add(source);
      for (final card in available[source]!) {
        final slot = _slotId(card);
        usedSlots.add(slot);
        targets[source] = card;
        final next = {
          ...remaining,
          for (final nested in sourcesFor(selectedCards(source, card)))
            if (!resolved.contains(nested)) nested,
        };
        if (assign(next, manualLeft, keepPrevious: keepPrevious)) return true;
        targets.remove(source);
        usedSlots.remove(slot);
      }
      if (manualLeft > 0 &&
          extras.containsKey(source) &&
          !(keepPrevious && retained.containsKey(source)) &&
          assign(remaining, manualLeft - 1, keepPrevious: keepPrevious)) {
        return true;
      }
      resolved.remove(source);
      return false;
    }

    var solved = false;
    for (var omissions = 0; omissions <= extras.length; omissions++) {
      solved = assign(initialSources, omissions, keepPrevious: true) ||
          (!validatePrevious &&
              retained.isNotEmpty &&
              assign(initialSources, omissions, keepPrevious: false));
      if (solved) break;
    }
    if (!solved) {
      conflict('The selected Ally or Prophecy conflicts with this kingdom. '
          'Check the required card type or unlock the landscape.');
    }
    for (final source in requiredTypes.keys) {
      if (targets.remove(source) case final card?) landscape.add(card);
    }
    for (final entry in targets.entries) {
      final cards = selectedCards(entry.key, entry.value);
      additional.addAll(cards);
      if (extras[entry.key]!.supply) supply.addAll(cards);
    }

    final traitCards = supply.where((card) => card.isAction || card.isTreasure);
    final traitPiles = <String, KingdomCard>{};
    for (final card in traitCards) {
      final slot = _slotId(card);
      final top = traitPiles[slot];
      if (top == null ||
          card.cost < top.cost ||
          (card.cost == top.cost && card.id.compareTo(top.id) < 0)) {
        traitPiles[slot] = card;
      }
    }
    if (landscape.any((card) => card.id == 'obelisk')) {
      final options = traitPiles.values.where((card) => card.isAction).toList();
      if (supply.any((card) => card.isLooter)) {
        final ruins = (catalogue.isEmpty ? eligible : catalogue)
            .where((card) => card.id == 'ruins')
            .firstOrNull;
        if (ruins != null) options.add(ruins);
      }
      if (options.isNotEmpty) {
        targets['obelisk'] = options
                .where((card) => card.id == previous['obelisk'])
                .firstOrNull ??
            options[_rng.nextInt(options.length)];
      }
    }
    final traits = landscape.where((card) => card.isTrait).toList();
    for (final trait in traits) {
      final retained = traitCards
          .where((card) =>
              card.id == previous[trait.id] &&
              traitPiles.containsKey(_slotId(card)))
          .firstOrNull;
      if (retained == null) continue;
      targets[trait.id] = retained;
      traitPiles.remove(_slotId(retained));
    }
    for (final trait in traits) {
      if (targets.containsKey(trait.id) || traitPiles.isEmpty) continue;
      final picked =
          traitPiles.values.elementAt(_rng.nextInt(traitPiles.length));
      targets[trait.id] = picked;
      traitPiles.remove(_slotId(picked));
    }
    if ([...kingdom, ...additional, ...blackMarketDeck]
        .any((card) => card.id == 'druid')) {
      final boons = (catalogue.isEmpty ? eligible : catalogue)
          .where((card) => card.types.contains(CardType.boon))
          .toList()
        ..shuffle(_rng);
      final savedCount = _druidBoonSlots.where(previous.containsKey).length;
      if (validatePrevious && savedCount > 0 && savedCount != 3) {
        throw const FormatException(invalidSetupChoice);
      }
      if (boons.length >= 3) {
        for (final source in _druidBoonSlots) {
          final saved =
              boons.where((card) => card.id == previous[source]).firstOrNull;
          if (saved == null) continue;
          targets[source] = saved;
          boons.remove(saved);
        }
        for (final source in _druidBoonSlots) {
          targets.putIfAbsent(source, () => boons.removeLast());
        }
      }
    }
    final ids = targets.map((source, target) => MapEntry(source, target.id));
    if (validatePrevious &&
        previous.entries.any((entry) => ids[entry.key] != entry.value)) {
      throw const FormatException(invalidSetupChoice);
    }
    return result.copyWith(
      landscapeCards: landscape,
      setupChoices: Map.unmodifiable(ids),
      setupNotes: generateSetupNotes([...kingdom, ...additional], landscape,
          targets: targets,
          allCards: catalogue,
          blackMarketDeck: blackMarketDeck),
    );
  }

  /// Cost and exclusion rules apply to every member of a physical pile.
  List<KingdomCard> eligibleKingdomPool(
      List<KingdomCard> all, Set<Expansion> owned, SetupRules rules,
      {Set<String> excludedCardIds = const {}}) {
    final pool = _stepAKingdomPool(all, owned);
    pool.removeWhere((card) => excludedCardIds.contains(card.id));
    _stepCApplyRules(pool, rules);
    final ids = pool.map((card) => card.id).toSet();
    final excludedPiles = all
        .where((card) => card.splitPileId != null && !ids.contains(card.id))
        .map((card) => card.splitPileId)
        .toSet();
    pool.removeWhere((card) => excludedPiles.contains(card.splitPileId));
    return pool;
  }

  /// Reports conflicts the eligible pool alone can prove before rolling.
  SetupException? poolConflict(List<KingdomCard> pool, SetupRules rules) {
    final slots = pool.map(_slotId).toSet();
    if (slots.length < 10) {
      return SetupException(
        'Only ${slots.length} eligible piles remain. Enable more expansions or relax your bans and rules.',
        SetupFailureReason.poolTooSmall,
      );
    }

    final canUseAttacks =
        !rules.requireReactionIfAttacks || pool.any((card) => card.isReaction);
    final attackSlots =
        pool.where((card) => card.isAttack).map(_slotId).toSet();
    final attackLimit = canUseAttacks ? (rules.maxAttacks ?? 10) : 0;
    final availableSlots = slots.length -
        attackSlots.length +
        min(attackSlots.length, attackLimit);
    if (availableSlots < 10) {
      return SetupException(
        canUseAttacks
            ? 'Only $availableSlots piles fit the attack limit. Raise the limit or enable expansions with more non-Attack piles.'
            : 'Too few non-Attack piles remain and there is no Reaction pile. Enable more expansions or turn off Auto-Reaction.',
        SetupFailureReason.requirementImpossible,
      );
    }

    final permitted = attackLimit == 0
        ? pool.where((card) => !attackSlots.contains(_slotId(card)))
        : pool;
    for (final requirement in _requirements(rules)) {
      if (!permitted.any(requirement.matches)) {
        return SetupException(
          'No permitted ${requirement.label} pile remains. Adjust your bans or expansions, or turn off Require ${requirement.label}.',
          SetupFailureReason.requirementImpossible,
        );
      }
    }
    if (permitted.map((card) => card.expansion).toSet().length <
        rules.minExpansionVariety) {
      return const SetupException(
        'The remaining piles cover too few expansions. Enable more expansions or lower the minimum variety.',
        SetupFailureReason.varietyImpossible,
      );
    }
    return null;
  }

  List<({String label, bool Function(KingdomCard) matches})> _requirements(
          SetupRules rules) =>
      [
        if (rules.requireVillage)
          (label: 'Village', matches: (card) => card.providesExtraActions),
        if (rules.requireTrashing)
          (label: 'Trashing', matches: (card) => card.trashesOwnCards),
        if (rules.requirePlusBuy)
          (label: '+Buy', matches: (card) => card.hasTag(CardTag.plusBuy)),
        if (rules.requireDraw)
          (label: 'Draw', matches: (card) => card.providesDraw),
      ];

  /// Tests each replacement against the same hard rules used by generation.
  Map<String, PileReplacement> replacementOptions({
    required List<KingdomCard> allCards,
    required Set<Expansion> ownedExpansions,
    required SetupRules rules,
    required SetupResult current,
    required String outgoingSlotId,
    String? incomingSlotId,
    Set<String> excludedCardIds = const {},
  }) {
    final selected = current.kingdomSlotIds;
    if (!selected.contains(outgoingSlotId) ||
        current.isSlotLocked(outgoingSlotId)) {
      throw const SetupException('Choose an unlocked pile to replace.',
          SetupFailureReason.requirementImpossible);
    }
    final pool = eligibleKingdomPool(allCards, ownedExpansions, rules,
        excludedCardIds: excludedCardIds);
    final eligibleById = {for (final card in pool) card.id: card};
    final retained = <KingdomCard>[];
    for (final card in current.kingdomCards) {
      if (_slotId(card) == outgoingSlotId) continue;
      final eligible = eligibleById[card.id];
      if (eligible == null) {
        throw SetupException(
            '${card.name} cannot be kept under the current collection and bans.',
            SetupFailureReason.requirementImpossible);
      }
      retained.add(eligible);
    }
    final landscapePool = _stepALandscapePool(allCards, ownedExpansions, rules);
    landscapePool.removeWhere((card) => excludedCardIds.contains(card.id));
    final landscapesById = {for (final card in landscapePool) card.id: card};
    final keep = <KingdomCard>[];
    for (final card in current.landscapeCards) {
      final eligible = landscapesById[card.id];
      if (eligible != null) {
        keep.add(eligible);
      } else if (current.isLandscapeLocked(card.id) ||
          (!card.isAlly && !card.isProphecy)) {
        return {};
      }
    }
    final alternatives = <String, List<KingdomCard>>{};
    for (final card in pool) {
      final slot = _slotId(card);
      if (!selected.contains(slot) &&
          (incomingSlotId == null || slot == incomingSlotId)) {
        (alternatives[slot] ??= []).add(card);
      }
    }

    final options = <String, PileReplacement>{};
    for (final entry in alternatives.entries) {
      final kingdom = [...retained, ...entry.value];
      try {
        validateKingdom(kingdom, pool, rules, retained);
        // Use the same prospective setup when rechecking a selected option.
        final engine = SetupEngine(
            random: Random(current.generatedAt.millisecondsSinceEpoch ^
                entry.key.hashCode));
        final table = engine.completeTableSetup(
          current.copyWith(kingdomCards: kingdom, landscapeCards: keep),
          pool,
          previous: current.setupChoices,
          rules: rules,
          excludedCardIds: excludedCardIds,
          landscapePool: landscapePool,
          keepRequiredLandscapes: false,
          catalogue: allCards,
        );
        options[entry.key] = (
          cards: entry.value,
          landscapes: table.landscapeCards,
          setupChoices: table.setupChoices,
          setupNotes: table.setupNotes,
        );
      } on SetupException {
        continue;
      }
    }
    return options;
  }

  List<KingdomCard> _selectKingdomForRules(
    List<KingdomCard> pool,
    SetupRules rules, {
    GameVibePreset? preset,
    List<KingdomCard> lockedKingdomCards = const [],
    required Set<String> recentSlots,
  }) {
    final scoreCurve = rules.costCurve.enabled && rules.costCurve.isValid;
    final scorePreset = preset != null && preset.id != GameVibePresets.noneId;
    final scoreFreshness = recentSlots.isNotEmpty &&
        pool.any((card) => recentSlots.contains(_slotId(card))) &&
        pool.any((card) => !recentSlots.contains(_slotId(card)));
    final shouldSearch = scoreCurve || scorePreset || scoreFreshness;
    _CurveCandidate? best;
    SetupException? lastFailure;
    final budget = scoreCurve ? _costCurveSearchBudget : _presetSearchBudget;
    for (var i = 0; i < budget; i++) {
      try {
        final (kingdom, locked) = _stepDSelect(
          pool,
          rules,
          seedCards: lockedKingdomCards,
        );
        if (rules.requireReactionIfAttacks) {
          _stepFAutoReaction(kingdom, locked, pool);
        }
        validateKingdom(kingdom, pool, rules, lockedKingdomCards);
        if (!shouldSearch) return kingdom;
        final repeats = scoreFreshness
            ? kingdom.map(_slotId).toSet().intersection(recentSlots).length
            : 0;
        if (!scoreCurve && !scorePreset && repeats == 0) return kingdom;
        final curveScore =
            scoreCurve ? _scoreCostCurve(kingdom, rules.costCurve) : null;
        final presetScore =
            scorePreset ? _scorePresetKingdom(kingdom, preset) : 0.0;
        final candidate = _CurveCandidate(
          kingdom: kingdom,
          score: curveScore,
          presetScore: presetScore,
          repeatCount: repeats,
        );
        if (best == null || candidate.isBetterThan(best)) {
          best = candidate;
        }
      } on SetupException catch (error) {
        lastFailure = error;
      }
    }

    if (best != null) return best.kingdom;
    throw SetupException(
      'Could not find a kingdom satisfying these constraints. ${lastFailure?.message ?? 'Try relaxing a rule or unlocking a pile.'}',
      lastFailure?.reason ?? SetupFailureReason.requirementImpossible,
    );
  }

  /// Check the final board after all swaps, since a locally valid replacement
  /// can invalidate a requirement elsewhere in the selection pipeline.
  void validateKingdom(List<KingdomCard> kingdom, List<KingdomCard> pool,
      SetupRules rules, List<KingdomCard> locked) {
    final ids = kingdom.map((card) => card.id).toSet();
    final slots = kingdom.map(_slotId).toSet();
    final allowed = pool.map((card) => card.id).toSet();
    void require(bool valid, String message) {
      if (!valid) {
        throw SetupException(message, SetupFailureReason.requirementImpossible);
      }
    }

    require(slots.length == 10 && ids.length == kingdom.length,
        'A kingdom must contain exactly ten unique piles.');
    require(ids.difference(allowed).isEmpty,
        'A selected card violates the pool filters.');
    require(locked.every((card) => ids.contains(card.id)),
        'A locked pile was changed.');
    require(
        pool
            .where((card) => slots.contains(_slotId(card)))
            .every((card) => ids.contains(card.id)),
        'A split pile is incomplete.');
    for (final requirement in _requirements(rules)) {
      require(kingdom.any(requirement.matches),
          'Require ${requirement.label} is not satisfied.');
    }
    final attacks =
        kingdom.where((card) => card.isAttack).map(_slotId).toSet().length;
    require(rules.maxAttacks == null || attacks <= rules.maxAttacks!,
        'The attack limit is exceeded.');
    require(
        !rules.requireReactionIfAttacks ||
            attacks == 0 ||
            kingdom.any((card) => card.isReaction),
        'Attacks require an available Reaction pile.');
    if (kingdom.map((card) => card.expansion).toSet().length <
        rules.minExpansionVariety) {
      throw const SetupException(
          'The minimum expansion variety is not satisfied.',
          SetupFailureReason.varietyImpossible);
    }
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
    SetupRules rules,
  ) =>
      all
          .where((c) =>
              owned.contains(c.expansion) &&
              c.isLandscape &&
              (!rules.noHighSetup ||
                  c.metadata.setupWeight != SetupWeight.high))
          .toList();

  // ===========================================================================
  // Step B — Manual exclusions
  // ===========================================================================

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
      if (rules.noHighSetup && c.metadata.setupWeight == SetupWeight.high) {
        return true;
      }
      if (rules.noTravellers && (c.isTraveller || c.hasExchangeChain)) {
        return true;
      }
      if (rules.maxCost != null && c.cost > rules.maxCost!) return true;
      return false;
    });
  }

  // ===========================================================================
  // Step D — Selection (split-pile aware)
  // ===========================================================================

  (List<KingdomCard>, List<KingdomCard>) _stepDSelect(
    List<KingdomCard> pool,
    SetupRules rules, {
    List<KingdomCard> seedCards = const [],
  }) {
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

    final seededSlotIds = seedCards.map(_slotId).toSet();
    for (final card in seedCards) {
      if (!kingdom.any((existing) => existing.id == card.id)) {
        kingdom.add(card);
        locked.add(card);
      }
    }
    pileReps.removeWhere((rep) => seededSlotIds.contains(_slotId(rep)));
    slotsSelected = seededSlotIds.length;

    // ── Phase 1: required slots ─────────────────────────────────────────────

    void reserveSlot(
      bool Function(KingdomCard) matcher,
      String ruleName,
    ) {
      if (kingdom.any(matcher)) return;
      if (slotsSelected >= 10) {
        throw SetupException(
          'Unlock a kingdom pile to satisfy "$ruleName".',
          SetupFailureReason.requirementImpossible,
        );
      }
      final attacks =
          kingdom.where((card) => card.isAttack).map(_slotId).toSet().length;
      final candidates = pileReps.where((rep) {
        final members = _allCardsForRep(rep, splitGroups);
        return members.any(matcher) &&
            (rules.maxAttacks == null ||
                !members.any((card) => card.isAttack) ||
                attacks < rules.maxAttacks!);
      }).toList();
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

    for (final requirement in _requirements(rules)) {
      reserveSlot(requirement.matches, 'Require ${requirement.label}');
    }

    // ── Phase 2: random fill ────────────────────────────────────────────────

    int attacksInKingdom =
        kingdom.where((c) => c.isAttack).map(_slotId).toSet().length;
    if (rules.maxAttacks != null && attacksInKingdom > rules.maxAttacks!) {
      throw const SetupException(
          'Locked piles exceed the attack limit. Unlock an Attack pile or increase the limit.',
          SetupFailureReason.requirementImpossible);
    }

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
    final lockedSlots = locked.map((c) => c.pileId).toSet().length;

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

  String _slotId(KingdomCard card) => card.pileId;

  Map<String, int> _costBucketCounts(List<KingdomCard> kingdom) {
    final slots = <String, int>{};
    for (final card in kingdom) {
      final slotId = _slotId(card);
      final current = slots[slotId];
      if (current == null || card.cost < current) {
        slots[slotId] = card.cost;
      }
    }

    final counts = <String, int>{
      '<=2': 0,
      '3': 0,
      '4': 0,
      '5': 0,
      '6+': 0,
    };

    for (final cost in slots.values) {
      if (cost <= 2) {
        counts['<=2'] = counts['<=2']! + 1;
      } else if (cost == 3) {
        counts['3'] = counts['3']! + 1;
      } else if (cost == 4) {
        counts['4'] = counts['4']! + 1;
      } else if (cost == 5) {
        counts['5'] = counts['5']! + 1;
      } else {
        counts['6+'] = counts['6+']! + 1;
      }
    }

    return counts;
  }

  _CurveScore _scoreCostCurve(List<KingdomCard> kingdom, CostCurveRule rule) {
    final actual = _costBucketCounts(kingdom);
    final target = rule.bucketCounts;
    var penalty = 0;
    var exactBuckets = 0;

    for (final key in target.keys) {
      final diff = (target[key]! - (actual[key] ?? 0)).abs();
      penalty += diff;
      if (diff == 0) exactBuckets++;
    }

    return _CurveScore(
      penalty: penalty,
      exactBuckets: exactBuckets,
      matchedSlots: _matchedCurveSlots(rule, actual),
    );
  }

  int _matchedCurveSlots(CostCurveRule rule, Map<String, int> actual) {
    final target = rule.bucketCounts;
    var matched = 0;
    for (final key in target.keys) {
      matched += min(target[key]!, actual[key] ?? 0);
    }
    return matched;
  }

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

    final outgoingSlot = _slotId(preferredSwappable.first);
    final incomingSlot = _slotId(reactions.first);
    kingdom.removeWhere((card) => _slotId(card) == outgoingSlot);
    kingdom.addAll(filteredPool.where((card) => _slotId(card) == incomingSlot));
  }

  // ===========================================================================
  // Step E — Landscape cards
  // ===========================================================================

  /// Draws landscape cards according to per-type counts in [rules].
  List<KingdomCard> _stepESelectLandscape(
    List<KingdomCard> pool,
    SetupRules rules, {
    List<KingdomCard> lockedLandscapeCards = const [],
  }) {
    final result = <KingdomCard>[...lockedLandscapeCards];
    final allowedIds = pool.map((card) => card.id).toSet();
    if (lockedLandscapeCards.any((card) => !allowedIds.contains(card.id))) {
      throw const SetupException(
          'A locked landscape is banned or outside the selected expansions.',
          SetupFailureReason.requirementImpossible);
    }
    final shuffled = [...pool]..shuffle(_rng);
    final lockedIds = lockedLandscapeCards.map((card) => card.id).toSet();

    void draw(bool Function(KingdomCard) filter, int count) {
      if (count <= 0) return;
      final remaining =
          count - result.where(filter).map((card) => card.id).toSet().length;
      if (remaining <= 0) return;
      final candidates = shuffled
          .where((card) => !lockedIds.contains(card.id) && filter(card))
          .toList();
      result.addAll(candidates.take(remaining.clamp(0, candidates.length)));
    }

    if (rules.includeLandscape) {
      draw((c) => c.isEvent, rules.landscapeEvents);
      draw((c) => c.isLandmark, rules.landscapeLandmarks);
      draw((c) => c.isProject, rules.landscapeProjects);
      draw((c) => c.isWay, rules.landscapeWays);
      draw((c) => c.isTrait, rules.landscapeTraits);
    }

    return result;
  }

  double _scorePresetKingdom(List<KingdomCard> kingdom, GameVibePreset preset) {
    return kingdom.fold<double>(
      0,
      (sum, card) => sum + preset.scoreCard(card.metadata),
    );
  }

  List<String> _generateSelectionRationale({
    required List<KingdomCard> kingdom,
    required SetupRules rules,
    required GameVibePreset? preset,
  }) {
    final lines = <String>[];
    if (preset != null && preset.id != GameVibePresets.noneId) {
      lines.add(preset.rationale);
    }

    final engineCount = kingdom
        .where((card) => card.metadata.engineSupport == EngineSupportLevel.high)
        .length;
    final attackCount = kingdom
        .where(
          (card) =>
              card.metadata.interactionProfile ==
              InteractionProfile.attackHeavy,
        )
        .length;
    final lowSetupCount = kingdom
        .where((card) => card.metadata.setupWeight == SetupWeight.low)
        .length;

    if (engineCount >= 3) {
      lines.add(
          'The board includes strong engine pieces with villages, draw, or clean support cards.');
    }
    if (attackCount >= 2) {
      lines.add(
          'Several interactive or attack-heavy cards push the kingdom toward player tension.');
    }
    if (lowSetupCount >= 6) {
      lines.add(
          'Most kingdom cards are light on setup overhead, so this board should come together quickly.');
    }
    if (rules.costCurve.enabled && rules.costCurve.isValid) {
      lines.add(
          'The final board was chosen from multiple candidates to stay close to your target cost curve.');
    }
    return lines;
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

      if (swappable.isEmpty) break;
      final overExp = _mostRepresentedExpansion(kingdom, locked);
      final evictPool = swappable.where((c) => c.expansion == overExp).toList();
      final evict = evictPool.isNotEmpty
          ? evictPool[_rng.nextInt(evictPool.length)]
          : swappable[_rng.nextInt(swappable.length)];

      _replacePile(
          kingdom: kingdom,
          outgoing: evict,
          incoming: candidate,
          splitGroups: splitGroups);
      swappable.removeWhere((card) => _slotId(card) == _slotId(evict));
      swappable.addAll(_allCardsForRep(candidate, splitGroups));
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

  List<String> generateSetupNotes(
    List<KingdomCard> kingdom,
    List<KingdomCard> landscape, {
    Map<String, KingdomCard> targets = const {},
    List<KingdomCard> allCards = const [],
    List<KingdomCard>? blackMarketDeck,
  }) {
    final physicalPiles = kingdom;
    kingdom = [...kingdom, ...?blackMarketDeck];
    final notes = <String>[];
    final kingdomExp = kingdom.map((c) => c.expansion).toSet();
    final allPresent = {...kingdomExp, ...landscape.map((c) => c.expansion)};
    final setupCards = [...kingdom, ...landscape];
    final dependencies =
        setupCards.expand((card) => card.capabilities.dependencies).toSet();

    if (setupCards.any((card) => card.isDuration)) {
      notes
          .add('Duration cards: keep them in play while future effects remain. '
              'If a Duration card leaves play, its future effects stop.');
    }

    if (landscape.any((card) => card.id == 'obelisk')) {
      final target = targets['obelisk'];
      notes.add(target == null
          ? 'Obelisk: choose an Action Supply pile if one is available.'
          : 'Obelisk: mark the ${target.name} Supply pile. At scoring, each '
              'card from that pile is worth 2 extra VP, including all of its '
              'different card names.');
    }

    if (dependencies.contains(SetupDependency.islandMat)) {
      notes.add('Island: have one Island mat per player ready. Take a mat when '
          'you first set a card aside with Island.');
    }

    if (dependencies.contains(SetupDependency.nativeVillageMat)) {
      notes.add('Native Village: have one Native Village mat per player ready. '
          'Take a mat when you first set a card aside with Native Village.');
    }

    if (dependencies.contains(SetupDependency.embargoTokens)) {
      notes.add('Embargo: set out the Embargo tokens.');
    }
    if (dependencies.contains(SetupDependency.pirateShipMat)) {
      notes.add('Pirate Ship: have one Pirate Ship mat per player and Coin '
          'tokens ready. Each mat starts empty.');
    }
    if (dependencies.contains(SetupDependency.tradeRouteMat)) {
      notes.add(
          'Trade Route: set out the Trade Route mat. Place one Coin token '
          'on each Victory Supply pile, including any extra Victory piles and '
          'Colony if used. Move a pile’s token to the mat on the first gain from it.');
    }

    // Prosperity: optional Platinum & Colony
    if (allPresent.any((e) =>
        e == Expansion.prosperity || e == Expansion.prosperitySecondEdition)) {
      notes.add(
        'Prosperity cards present: if using Platinum and Colony, add both piles alongside Gold and Province.',
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
        '(the coin-shaped cardboard tokens). Pay \$1 per Debt token at any '
        'time on your turn. Clear your Debt before buying cards, Events or '
        'Projects.',
      );
    }

    if (setupCards.any((c) =>
        c.hasTag(CardTag.coffers) || c.id == 'joust' || c.id == 'footpad')) {
      notes.add(
        'Coffers present: prepare Coin tokens and Coffers mats. '
        'Each player starts with 0 Coffers unless Baker is present.',
      );
    }

    if (setupCards.any((card) => card.id == 'tournament')) {
      notes.add('Tournament: set out one copy each of Bag of Gold, Diadem, '
          'Followers, Princess, and Trusty Steed as Prizes beside the Supply.');
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

    if (kingdom.any((c) => c.name == 'Black Market')) {
      if (blackMarketDeck != null) {
        notes.add('Black Market deck (${blackMarketDeck.length} cards): '
            '${blackMarketDeck.map((card) => card.name).join(', ')}. '
            'Show these contents to all players, take one of each, then shuffle '
            'face down. These cards have no Supply pile and cannot be exchanged '
            'or returned to a pile.');
        if (blackMarketDeck.length < 15) {
          notes.add(
              'Fewer than 15 unused permitted piles remain for Black Market '
              'after other setup choices. Enable more cards for a larger deck.');
        }
      }
      notes.add(
        'Black Market present: make a Black Market deck from different unused '
        'Kingdom cards that are not otherwise in the Supply or set aside for '
        'other setup effects. Agree on its contents before playing; at least '
        '15 cards are recommended. Use one copy of each selected card, '
        'shuffled face down. Do all setup those cards require, including '
        'their "in games using this" effects, even if they are never revealed. '
        'If that deck contains any Potion-cost cards, include the Potion '
        'Supply pile with all 16 Potions.',
      );
    }

    if (kingdom.any((c) => c.name == 'Footpad')) {
      notes.add(
        'Footpad present: for the whole game, whenever a player gains a card '
        'during an Action phase, that player draws a card.',
      );
    }
    if (kingdom.any((card) => card.id == 'charlatan')) {
      notes.add('Charlatan present: for the whole game, Curses are also '
          'Treasures producing \$1. They remain Curses worth -1VP.');
    }
    if (kingdom.any((card) => card.id == 'shaman')) {
      notes.add('Shaman present: for the whole game, at the start of each '
          'player\'s turn, that player must gain a card costing up to \$6 '
          'from the trash if possible.');
    }

    if (kingdom.any((c) => c.id == 'ferryman')) {
      final target = targets['ferryman'];
      notes.add(
        target == null
            ? 'Ferryman: choose an unused \$3 or \$4 Kingdom pile and place it outside the Supply.'
            : 'Ferryman: put the ${target.name} pile beside the Supply. When gaining Ferryman, also gain a card from that pile.',
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
        c.pileCardIds.any(_plunderLootIds.contains) ||
        c.pileCards.any((name) =>
            _plunderLootIds.contains(name.toLowerCase().replaceAll(' ', '_'))));
    if (usesLootPile) {
      notes.add(
        'Loot pile present: shuffle all 30 Loot cards (two of each) face down '
        'beside the Supply. To gain a Loot, reveal and gain the top card. '
        'An empty Loot pile stays empty; no Loot is gained.',
      );
    }

    for (final trait in landscape.where((card) => card.isTrait)) {
      final target = targets[trait.id];
      notes.add(
        target == null
            ? '${trait.name} Trait: choose an Action or Treasure Kingdom pile without a Trait.'
            : '${trait.name} Trait: place it on the pile containing ${target.name}. It affects the entire pile.',
      );
      if (trait.id == 'inherited') {
        notes.add('Inherited starting decks: in turn order, each player '
            'replaces one starting card of their choice with the top card '
            'of ${target == null ? 'the chosen Inherited' : target.name} pile. '
            'Return replaced Coppers to the Supply; put replaced Estates, '
            'Shelters and Heirlooms back in the box. This is not gaining a '
            'card and does not trigger when-gain effects.');
      }
    }

    if (kingdom.any((c) => c.isShadow)) {
      notes.add(
        'Shadow cards present: when shuffling Shadow cards, put them on the '
        'bottom of your deck. You may play Shadow cards from your deck as if '
        'they were in your hand whenever you could normally play an Action, '
        'including when another card tells you to play one from your hand.',
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
        'Resolve +1 Sun before the Omen\'s other instructions: remove one '
        'token, and when the last is removed the Prophecy becomes active '
        'immediately for the rest of the game. Further +1 Sun does nothing.',
      );
      if (selectedProphecy.id == 'approaching_army') {
        final target = targets['approaching_army'];
        notes.add(
          target == null
              ? 'Approaching Army: choose an unused Attack Kingdom pile and add it to the Supply.'
              : 'Approaching Army: add the ${target.name} pile to the Supply as an extra Attack pile.',
        );
      }
    }

    if (kingdom.any((c) => c.id == 'riverboat')) {
      final target = targets['riverboat'];
      notes.add(
        target == null
            ? 'Riverboat: set aside one unused non-Duration Action card costing exactly \$5.'
            : 'Riverboat: set aside one copy of ${target.name}. It stays set aside when played.',
      );
    }

    if (kingdom.any((c) => c.id == 'young_witch')) {
      final target = targets['young_witch'];
      notes.add(
        target == null
            ? 'Young Witch: choose an unused \$2 or \$3 Kingdom pile as the Bane and add it to the Supply.'
            : 'Young Witch: add the ${target.name} pile to the Supply as the Bane pile.',
      );
    }

    final adventureCards = [
      ...kingdom.where((c) => c.expansion == Expansion.adventures),
      ...landscape.where((c) => c.expansion == Expansion.adventures),
    ];
    if (adventureCards.any((c) =>
        c.types.contains(CardType.reserve) ||
        c.id == 'miser' ||
        c.id == 'peasant')) {
      notes.add(
        'Tavern mats: give each player one for Reserve cards, Miser\'s '
        'Coppers, and Teacher from the Peasant exchange chain as needed.',
      );
    }

    if (physicalPiles.any((c) => c.name == 'Port')) {
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
        'Projects present: give each player two cubes of one color. Mark each '
        'purchased Project with a cube; each player can buy at most two '
        'different Projects and cannot remove their cubes.',
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
        'Artifacts present: set aside one of each: ${artifacts.join(', ')}. '
        'When instructed to take an Artifact, take it from its current holder '
        'or from beside the Supply if nobody has it.',
      );
    }

    final menagerieCards = setupCards
        .where((c) => c.expansion == Expansion.menagerie)
        .toList(growable: false);
    if (menagerieCards.any((c) => c.hasTag(CardTag.exile))) {
      notes.add(
        'Exile effects present: each player needs an Exile mat. When gaining '
        'a card, players may discard all copies of it from their Exile mat, '
        'or leave them all there. Exiling a card is not gaining or trashing it.',
      );
    }
    if (menagerieCards.any((c) => c.isWay)) {
      notes.add(
        'Ways present: when playing an Action, choose its normal on-play '
        'instructions or one Way. Text below a dividing line is unaffected.',
      );
    }

    if (menagerieCards.any((c) =>
        c.pileCardIds.contains('horse') ||
        c.pileCards.contains('Horse') ||
        c.name == 'Ride')) {
      notes.add(
        'Horse gainers present: set aside all 30 Horses; Horses are not in '
        'the Supply and return to their pile when played.',
      );
    }

    if (landscape.any((c) => c.id == 'way_of_the_mouse')) {
      final target = targets['way_of_the_mouse'];
      notes.add(
        target == null
            ? 'Way of the Mouse: set aside one unused non-Duration Action card costing \$2 or \$3.'
            : 'Way of the Mouse: set aside one copy of ${target.name}. It stays set aside when played.',
      );
    }

    if (setupCards.any((c) => c.hasTag(CardTag.pointTokens))) {
      notes.add('VP tokens: prepare the Victory Point token supply.');
    }

    if (physicalPiles.any((c) => c.name == 'Castles')) {
      notes.add(
        'Castles present: sort the Castle pile by cost with Humble Castle on '
        'top and King\'s Castle on the bottom. Use one of each Castle for '
        '2 players. With more players, use two each of Humble Castle, Small '
        'Castle, Opulent Castle, and King\'s Castle, and one each of the other '
        'Castles (12 cards total).',
      );
    }

    if (physicalPiles.any((c) => c.types.contains(CardType.gathering))) {
      notes.add(
        'Gathering pile present: VP tokens on Farmers\' Market, Temple, or '
        'Wild Hunt stay on their Supply pile until a card effect removes them.',
      );
    }

    if (landscape.any((card) => card.id == 'aqueduct')) {
      notes.add('Aqueduct: put 8 VP on Silver and 8 VP on Gold. '
          'The Landmark starts empty.');
    }
    if (landscape.any((card) => card.id == 'defiled_shrine')) {
      notes.add('Defiled Shrine: put 2 VP on each non-Gathering Action Supply '
          'pile, including extra Supply piles and Ruins when used. '
          'The Landmark starts empty.');
    }
    if (landscape.any((card) => card.id == 'tax')) {
      notes.add('Tax: put 1 Debt on every Supply pile, including base piles, '
          'extra Supply piles, and Potion or Ruins when used.');
    }

    // Dark Ages: Shelters
    if (kingdomExp.contains(Expansion.darkAges)) {
      notes.add(
        'Dark Ages present: when all ten main Kingdom piles are from Dark Ages, '
        'use Shelters. In a mixed kingdom, decide whether to use them. With '
        'Shelters, give each player one Hovel, one Necropolis and one Overgrown '
        'Estate instead of 3 starting Estates. The Estate Supply still has '
        '8 cards for 2 players or 12 for 3-6 players.',
      );
    }

    if (kingdom.any((c) => c.isLooter)) {
      notes.add(
        'Looter present: prepare and shuffle the Ruins pile '
        '(10 Ruins per player after the first), with the top card face up.',
      );
    }

    if (physicalPiles.any((c) => c.name == 'Knights')) {
      notes.add(
        'Knights present: shuffle the 10 Knights into one Supply pile and '
        'place the top Knight face up.',
      );
    }

    if (physicalPiles.any((c) => c.id == 'rats')) {
      notes.add(
          'Rats: use all 20 cards in its Supply pile for any player count.');
    }

    final specialPiles = <String>{
      if (kingdom.any((c) =>
          c.name == 'Bandit Camp' ||
          c.name == 'Marauder' ||
          c.name == 'Pillage'))
        '15 Spoils',
      if (kingdom.any((c) => c.name == 'Hermit')) '10 Madmen',
      if (kingdom.any((c) => c.name == 'Urchin')) '10 Mercenaries',
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
        'Fate cards present: shuffle the 12 Boons and set aside all 12 '
        'Will-o\'-Wisps outside the Supply.',
      );
    }

    if (kingdom.any((c) => c.id == 'druid')) {
      final boons = _druidBoonSlots
          .map((source) => targets[source])
          .whereType<KingdomCard>()
          .toList();
      notes.add(boons.length == 3
          ? 'Druid present: set aside ${boons.map((card) => card.name).join(', ')} '
              'face up for the whole game. Druid receives one of these without '
              'moving it. Other Fate cards use the remaining 9 Boons.'
          : 'Druid present: set aside the top 3 Boons face up; Druid chooses '
              'from those instead of the Boon deck. Other Fate cards use the '
              'remaining 9 Boons.');
    }

    if (nocturneCards.any((c) => c.types.contains(CardType.doom))) {
      notes.add(
        'Doom cards present: shuffle the 12 Hexes and prepare the State cards '
        '(6 double-sided Deluded/Envious and 6 Miserable/Twice Miserable).',
      );
    }

    final nocturnePiles = <String>{
      if (kingdom.any((c) => c.name == 'Necromancer'))
        'the 3 Zombies in the trash',
      if (kingdom.any((c) => c.name == 'Exorcist'))
        'all 12 Will-o\'-Wisps, 13 Imps, and 6 Ghosts (the Spirit piles)',
      if (kingdom.any((c) => c.name == 'Vampire')) 'all 10 Bats',
      if (kingdom.any((c) => c.name == 'Fool')) 'Lost in the Woods State',
      if (kingdom.any((c) => c.name == 'Leprechaun' || c.name == 'Secret Cave'))
        'all 12 Wishes',
      if (kingdom
          .any((c) => c.name == 'Devil\'s Workshop' || c.name == 'Tormentor'))
        'all 13 Imps',
      if (kingdom.any((c) => c.name == 'Cemetery')) 'all 6 Ghosts',
    };
    if (nocturnePiles.isNotEmpty) {
      notes.add(
        'Nocturne non-Supply cards: set aside ${nocturnePiles.join(', ')}.',
      );
    }

    // Traveller/exchange chains
    final byId = {for (final card in allCards) card.id: card};
    for (final c in kingdom.where((c) => c.isTraveller)) {
      final chain = c.travellerChainIds.isEmpty
          ? c.travellerChain.join(' → ')
          : [
              for (var i = 0; i < c.travellerChainIds.length; i++)
                byId[c.travellerChainIds[i]]?.name ??
                    (i < c.travellerChain.length
                        ? c.travellerChain[i]
                        : c.travellerChainIds[i])
            ].join(' → ');
      notes.add(
        '${c.name} has an exchange chain: have the set-aside card(s) available '
        '($chain). Set aside 5 copies of each upgrade outside the Supply.',
      );
    }

    // Allies / Favors
    if (kingdom.any((c) => c.isLiaison)) {
      final allyNames = landscape.where((c) => c.isAlly).map((c) => c.name);
      final startingFavors = kingdom.any((c) => c.name == 'Importer') ? 5 : 1;
      notes.add(
        'Liaison setup: set out ${allyNames.isEmpty ? 'one Ally' : allyNames.join(' / ')}, '
        'give each player a Favors mat, and start each player with '
        '$startingFavors Favor token${startingFavors == 1 ? '' : 's'}. '
        'Favors may be spent from the first turn onward, once per Ally '
        'trigger unless it says to repeat.',
      );
    }

    // Split piles — remind players to set the shared pile out
    final splitIds = physicalPiles
        .where((c) => c.isSplitPile)
        .map((c) => c.splitPileId!)
        .toSet();
    for (final id in splitIds) {
      final pile = physicalPiles.where((c) => c.splitPileId == id).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));
      if (pile.length > 2) {
        notes.add(
          'Rotating pile: ${pile.map((c) => c.name).join(' / ')} — place 4 '
          'copies of each card in one Supply pile (16 total) in cost order '
          'with ${pile.first.name} on top, '
          'and rotate it when instructed: move the top card and all '
          'identical cards directly beneath it to the bottom together.',
        );
      } else if (pile.length == 2) {
        notes.add(
          'Split pile: ${pile.map((c) => c.name).join(' / ')} — place both '
          'halves, 5 copies of each card (10 total), in a single Supply pile, '
          'lower-cost (${pile.first.name}) on top.',
        );
      }
    }

    if (kingdom.any((c) => c.isAttack) &&
        !kingdom.any((c) => c.blocksAttacks)) {
      notes.add(
        'Attacks are present. No Kingdom pile in this setup can make you '
        'unaffected by an Attack.',
      );
    }

    // Curses with no trashing
    if (kingdom.any((c) => c.hasTag(CardTag.curse)) &&
        !kingdom.any((c) => c.trashesOwnCards)) {
      notes.add(
        'Curse-giving cards present with no Trashing — consider prioritising '
        'Province timing to end the game before Curses pile up.',
      );
    }

    return notes;
  }
}

class _CurveCandidate {
  final List<KingdomCard> kingdom;
  final _CurveScore? score;
  final double presetScore;
  final int repeatCount;

  _CurveCandidate({
    required this.kingdom,
    required this.score,
    required this.presetScore,
    required this.repeatCount,
  });

  bool isBetterThan(_CurveCandidate other) {
    if (score != null && other.score != null) {
      if (score!.isBetterThan(other.score!)) return true;
      if (other.score!.isBetterThan(score!)) return false;
    }
    if (repeatCount != other.repeatCount) {
      return repeatCount < other.repeatCount;
    }
    if (presetScore != other.presetScore) {
      return presetScore > other.presetScore;
    }
    return false;
  }
}

class _CurveScore {
  final int penalty;
  final int exactBuckets;
  final int matchedSlots;

  const _CurveScore({
    required this.penalty,
    required this.exactBuckets,
    required this.matchedSlots,
  });

  bool isBetterThan(_CurveScore other) {
    if (penalty != other.penalty) return penalty < other.penalty;
    if (exactBuckets != other.exactBuckets) {
      return exactBuckets > other.exactBuckets;
    }
    if (matchedSlots != other.matchedSlots) {
      return matchedSlots > other.matchedSlots;
    }
    return false;
  }
}

/// Validate resolved selections before importing; labels alone cannot prove a
/// complete kingdom because duplicates and split piles change the slot count.
void validateImportedKingdom(
  Iterable<KingdomCard> catalogue,
  List<KingdomCard> kingdom, {
  List<KingdomCard> landscapes = const [],
}) {
  final ids = kingdom.map((card) => card.id).toSet();
  final slots = kingdom.map((card) => card.pileId).toSet();
  if (ids.length != kingdom.length || slots.length != 10) {
    throw const FormatException(
        'A kingdom must contain exactly 10 unique piles. Check for duplicate cards.');
  }
  if (kingdom.any((card) => !card.isKingdomCard)) {
    throw const FormatException('Auxiliary cards cannot fill kingdom slots.');
  }
  final selectedPiles =
      kingdom.map((card) => card.splitPileId).whereType<String>().toSet();
  for (final card in catalogue) {
    if (selectedPiles.contains(card.splitPileId) && !ids.contains(card.id)) {
      throw FormatException('Incomplete split pile: missing ${card.name}.');
    }
  }
  if (landscapes.map((card) => card.id).toSet().length != landscapes.length ||
      landscapes.any((card) => !card.isLandscape)) {
    throw const FormatException(
        'Landscape selection contains duplicates or non-landscape cards.');
  }
}
