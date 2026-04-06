import '../models/card_tag.dart';
import '../models/dominion_card.dart';
import '../models/setup_result.dart';
import '../models/strategy_archetype.dart';

/// Analyses a 10-card kingdom and emits ranked [StrategyArchetype] objects.
///
/// Scoring is tag-based: each tag on each card contributes a weighted point
/// value toward one or more archetypes. Only archetypes that exceed their
/// raw-score threshold are returned; results are sorted strongest-first.
///
/// Usage:
/// ```dart
/// final archetypes = HeuristicEngine().analyze(kingdom);
/// ```
class HeuristicEngine {
  /// Entry point. Returns 1-4 archetypes, strongest first.
  List<StrategyArchetype> analyze(List<DominionCard> kingdom) {
    final profile = _KingdomProfile(kingdom);

    final candidates = [
      _scoreEngineBuilding(profile),
      _scoreBigMoney(profile),
      _scoreAggressiveControl(profile),
      _scoreTrashToVictory(profile),
      _scoreAltVictory(profile),
      _scoreMirrorMatch(profile),
    ].whereType<StrategyArchetype>().toList();

    candidates.sort((a, b) => b.strength.compareTo(a.strength));
    return candidates;
  }

  /// Convenience: fills the empty [SetupResult.archetypes] produced by
  /// [SetupEngine] and returns a new result with everything populated.
  SetupResult enrich(SetupResult result) {
    return SetupResult(
      kingdomCards: result.kingdomCards,
      archetypes:   analyze(result.kingdomCards),
      setupNotes:   result.setupNotes,
      generatedAt:  result.generatedAt,
    );
  }

  // ===========================================================================
  // Pre-computed kingdom profile
  // ===========================================================================

  // ===========================================================================
  // Archetype: Engine Building
  //
  // Triggered by: villages (action-chain enablers) + draw cards working together.
  // A real engine needs BOTH: cards that give extra Actions AND cards that draw.
  // Strong: 2+ villages + 2+ draw cards.  Weak: 1 village + some draw.
  // Threshold: raw >= 5.0
  // ===========================================================================

  static const double _engineThreshold = 5.0;
  static const double _engineMax       = 14.0;

  StrategyArchetype? _scoreEngineBuilding(_KingdomProfile p) {
    double score = 0;

    for (final c in p.kingdom) {
      // Village role — the backbone of any engine
      if (c.hasTag(CardTag.villageEffect)) {
        score += 2.5;
      } else if (c.hasTag(CardTag.plusTwoActions)) {
        score += 2.0;
      } else if (c.hasTag(CardTag.plusAction)) {
        score += 0.6;
      }

      // Draw role
      if (c.hasTag(CardTag.drawToX)) {
        score += 2.0;
      } else if (c.hasTag(CardTag.plusCard)) {
        score += 1.2;
      }

      // Support roles
      if (c.hasTag(CardTag.sifting))    score += 0.7;
      if (c.hasTag(CardTag.coffers))    score += 0.5;
      if (c.hasTag(CardTag.villagers))  score += 0.8;
    }

    // Require at least one action-chainer AND one draw source for a true engine
    if (p.villageCount == 0 && p.plusActionCount < 2) return null;
    if (p.drawCount == 0) return null;
    if (score < _engineThreshold) return null;

    return StrategyArchetype(
      kind:         ArchetypeKind.engineBuilding,
      headline:     _engineHeadline(p),
      description:  _engineDescription(p),
      tips:         _engineTips(p),
      keyCardNames: _engineKeyCards(p),
      strength:     (score / _engineMax).clamp(0.0, 1.0),
    );
  }

  String _engineHeadline(_KingdomProfile p) {
    if (p.villageCount >= 3) return 'Full Mega-Engine';
    if (p.villageCount >= 2) return 'Strong Action Engine';
    return 'Engine Building';
  }

  String _engineDescription(_KingdomProfile p) {
    final villages = p.cardsWithTag(CardTag.villageEffect).map((c) => c.name);
    final draws    = p.drawCards.map((c) => c.name);

    final villagePart = villages.isEmpty
        ? 'action chaining through ${p.cardsWithTag(CardTag.plusAction).map((c) => c.name).join(' and ')}'
        : 'villages (${villages.join(', ')})';

    final drawPart = draws.isEmpty ? 'card draw' : draws.join(' and ');

    final trashNote = p.trashCount > 0
        ? ' ${p.trashCards.first.name} lets you aggressively remove Copper and Estate to turbocharge the engine.'
        : '';

    return 'This kingdom supports an engine strategy built around $villagePart '
        'combined with $drawPart.$trashNote '
        'Execute your engine reliably before greening to maximise points.';
  }

  List<String> _engineTips(_KingdomProfile p) {
    final tips = <String>[];

    // Opening advice
    if (p.trashCount > 0 && p.trashCards.any((c) => c.hasTag(CardTag.trashForBenefit))) {
      final trasher = p.trashCards.firstWhere((c) => c.hasTag(CardTag.trashForBenefit));
      tips.add('Open with ${trasher.name} to trash Copper and Estates — a lean '
               '5-card deck churns through your engine far faster.');
    } else {
      tips.add('Open Silver / Silver (or Silver + village) to hit \$5 consistently '
               'before pivoting to engine pieces.');
    }

    // Village advice
    if (p.villageCount >= 2) {
      final vNames = p.cardsWithTag(CardTag.villageEffect).map((c) => c.name).join(' or ');
      tips.add('Buy 2–3 copies of $vNames early — without sufficient Actions '
               'your draw cards become dead terminals.');
    }

    // Draw advice
    if (p.cardsWithTag(CardTag.drawToX).isNotEmpty) {
      final drawer = p.cardsWithTag(CardTag.drawToX).first;
      tips.add('${drawer.name} draws to a fixed hand size — it gets stronger '
               'the smaller your deck is, so trash early and play it late.');
    } else if (p.drawCards.isNotEmpty) {
      final drawer = p.drawCards.first;
      tips.add('${drawer.name} is your primary draw engine; aim for 2–3 copies '
               'to ensure consistent cycling.');
    }

    // Sifting advice
    if (p.siftingCards.isNotEmpty) {
      tips.add('${p.siftingCards.first.name} helps filter your deck while '
               'the engine is still coming together — use it early and often.');
    }

    // Greening window
    tips.add('Start buying Provinces when your engine reliably generates '
             '\$8+. Greening too early interrupts the chain before you\'ve '
             'built enough momentum.');

    return tips;
  }

  List<String> _engineKeyCards(_KingdomProfile p) {
    return <String>{
      ...p.cardsWithTag(CardTag.villageEffect).map((c) => c.name),
      ...p.drawCards.take(2).map((c) => c.name),
      if (p.trashCount > 0) p.trashCards.first.name,
    }.take(4).toList();
  }

  // ===========================================================================
  // Archetype: Big Money / Slog
  //
  // Triggered by: coin generation without reliable action chaining, or heavy
  // terminal draw. Big Money is the baseline Dominion strategy and always
  // viable — but strongest when the kingdom has weak engine support.
  // Threshold: raw >= 2.0  (almost always shown unless a full engine exists)
  // ===========================================================================

  static const double _bigMoneyThreshold = 2.0;
  static const double _bigMoneyMax       = 12.0;

  StrategyArchetype? _scoreBigMoney(_KingdomProfile p) {
    double score = 0;

    for (final c in p.kingdom) {
      if (c.hasTag(CardTag.goldGain))    score += 2.0;
      if (c.hasTag(CardTag.gainTreasure)) score += 1.5;
      if (c.hasTag(CardTag.silverGain))  score += 1.0;
      if (c.hasTag(CardTag.plusCoin))    score += 0.8;
    }

    // Bonus if the kingdom has weak action chaining
    if (p.villageCount == 0) score += 2.0;
    if (p.drawCount <= 1)    score += 1.0;

    // Terminal draw is a classic Big Money synergy
    if (p.terminalDrawCount > 0) score += 1.5;

    if (score < _bigMoneyThreshold) return null;

    return StrategyArchetype(
      kind:         ArchetypeKind.bigMoney,
      headline:     _bigMoneyHeadline(p),
      description:  _bigMoneyDescription(p),
      tips:         _bigMoneyTips(p),
      keyCardNames: _bigMoneyKeyCards(p),
      strength:     (score / _bigMoneyMax).clamp(0.0, 1.0),
    );
  }

  String _bigMoneyHeadline(_KingdomProfile p) {
    if (p.villageCount == 0 && p.drawCount == 0) return 'Pure Big Money';
    if (p.terminalDrawCount > 0) return 'Big Money + Terminal Draw';
    return 'Big Money / Slog';
  }

  String _bigMoneyDescription(_KingdomProfile p) {
    final coinCards = p.kingdom.where((c) =>
        c.hasTag(CardTag.goldGain) || c.hasTag(CardTag.gainTreasure) ||
        c.hasTag(CardTag.plusCoin)).toList();

    final coinNote = coinCards.isEmpty
        ? 'Focus on buying Gold and Silver from the base supply'
        : '${coinCards.map((c) => c.name).join(', ')} accelerate your '
          'economy ahead of Province timing';

    final engineNote = p.villageCount == 0
        ? ' With no Villages available, multi-terminal engines are risky — '
          'limit yourself to 1–2 terminal Actions per deck cycle.'
        : '';

    return '$coinNote.$engineNote '
        'The goal is simple: generate \$8 as reliably as possible and buy '
        'Provinces before your opponent can set up a more complex strategy.';
  }

  List<String> _bigMoneyTips(_KingdomProfile p) {
    final tips = <String>[];

    // Open advice
    tips.add('Open Silver / Silver in most Big Money games — the early economy '
             'snowball is more valuable than any \$3 Kingdom card.');

    // Terminal draw synergy
    if (p.terminalDrawCount > 0) {
      final terminal = p.kingdom
          .firstWhere((c) => c.hasTag(CardTag.plusCard) && !c.hasTag(CardTag.plusAction));
      tips.add('${terminal.name} is your terminal draw engine. Buy 1–2 copies '
               'maximum — too many collide and strand your turns without Actions.');
    }

    // Coin acceleration
    final goldGainers = p.kingdom.where((c) => c.hasTag(CardTag.goldGain)).toList();
    if (goldGainers.isNotEmpty) {
      tips.add('${goldGainers.first.name} gains Gold directly — buy it early '
               'to rapidly inflate your average hand value.');
    }

    // Pile control
    tips.add('Watch your Province count carefully. In a Big Money game, '
             'greening pressure sets in at 5–6 Provinces — plan your last '
             'two turns to spike \$8 even with green cards diluting your deck.');

    // Attack interaction
    if (p.attackCount > 0) {
      tips.add('Attacks hurt Big Money more than engine decks (you rely on '
               'consistent hand size). If a Reaction is available, consider '
               'buying one copy as insurance.');
    }

    return tips;
  }

  List<String> _bigMoneyKeyCards(_KingdomProfile p) {
    return p.kingdom
        .where((c) =>
            c.hasTag(CardTag.goldGain) ||
            c.hasTag(CardTag.gainTreasure) ||
            c.hasTag(CardTag.plusCard) && !c.hasTag(CardTag.plusAction))
        .map((c) => c.name)
        .take(3)
        .toList();
  }

  // ===========================================================================
  // Archetype: Aggressive / Control
  //
  // Triggered by: 2+ Attack cards in the kingdom.
  // Sub-flavours: discard attacks slow hand size; junking/curse attacks clog
  // decks; topdeck attacks disrupt draw order.
  // Threshold: raw >= 4.0
  // ===========================================================================

  static const double _aggroThreshold = 4.0;
  static const double _aggroMax       = 16.0;

  StrategyArchetype? _scoreAggressiveControl(_KingdomProfile p) {
    if (p.attackCount < 2) return null;

    double score = p.attackCount * 2.0;
    score += p.discardAttackCount  * 0.8;
    score += p.curseAttackCount    * 1.2;
    score += p.junkingAttackCount  * 1.0;
    score += p.topdeckAttackCount  * 0.6;
    score += p.reactionCount       * 0.5; // reactions make mirroring interesting

    if (score < _aggroThreshold) return null;

    return StrategyArchetype(
      kind:         ArchetypeKind.aggressiveControl,
      headline:     _aggroHeadline(p),
      description:  _aggroDescription(p),
      tips:         _aggroTips(p),
      keyCardNames: _aggroKeyCards(p),
      strength:     (score / _aggroMax).clamp(0.0, 1.0),
    );
  }

  String _aggroHeadline(_KingdomProfile p) {
    if (p.curseAttackCount > 0 && p.junkingAttackCount > 0) return 'Junk Flood';
    if (p.curseAttackCount > 0) return 'Curse Slinging';
    if (p.discardAttackCount >= 2) return 'Hand Disruption';
    if (p.topdeckAttackCount > 0) return 'Deck Disruption';
    return 'Aggressive / Control';
  }

  String _aggroDescription(_KingdomProfile p) {
    final attackNames = p.attackCards.map((c) => c.name).join(', ');

    String flavour;
    if (p.curseAttackCount > 0) {
      flavour = 'Curse-giving attacks (${p.attackCards.where((c) => c.hasTag(CardTag.curse)).map((c) => c.name).join(', ')}) '
                'degrade opponents\' decks with unspendable Curses.';
    } else if (p.discardAttackCount >= 2) {
      flavour = 'Discard attacks force opponents to replay from a shrunken hand, '
                'dramatically slowing their ability to hit price points.';
    } else if (p.junkingAttackCount > 0) {
      flavour = 'Junking attacks load opponents\' decks with unwanted cards, '
                'diluting their draw and slowing their economy.';
    } else {
      flavour = 'Attacks ($attackNames) apply constant pressure that opponents '
                'must react to or fall behind.';
    }

    final reactionNote = p.reactionCount > 0
        ? ' A Reaction card is available — holding it in hand creates a '
          'meaningful tension between using hand space and blocking attacks.'
        : '';

    return '$flavour$reactionNote Race to play your attacks before opponents '
           'can build a stable defence or race to end the game on their terms.';
  }

  List<String> _aggroTips(_KingdomProfile p) {
    final tips = <String>[];

    // Priority buy
    final firstAttack = p.attackCards.first;
    tips.add('Prioritise ${firstAttack.name} early — Attacks compound in value '
             'when played before opponents have stabilised their decks.');

    if (p.curseAttackCount > 0) {
      final curser = p.attackCards.firstWhere((c) => c.hasTag(CardTag.curse));
      tips.add('${curser.name} hands out Curses — watch the Curse pile. '
               'If it empties, the game often ends on three-pile; plan around it.');
      tips.add('Distribute Curses as fast as possible before opponents can '
               'buy Trashers. Every Curse in an opponent\'s deck is worth '
               '-1 VP and a dead draw.');
    }

    if (p.discardAttackCount > 0) {
      final discarder = p.attackCards.firstWhere((c) => c.hasTag(CardTag.discard));
      tips.add('${discarder.name} disrupts hand size. Chain it with Actions '
               'that benefit from opponents having fewer cards (e.g., reaction-less kingdoms).');
    }

    if (p.reactionCount > 0) {
      final reactor = p.kingdom.firstWhere((c) => c.hasTag(CardTag.reaction));
      tips.add('${reactor.name} blocks attacks. In a mirror-match, buying '
               'one copy is often correct; buying two is usually excessive.');
    }

    // End-game note
    tips.add('Aggressive decks can force early game-endings via pile depletion. '
             'Track three-pile risk — empty the Curse pile + two cheap Kingdom '
             'piles to end the game on your schedule.');

    return tips;
  }

  List<String> _aggroKeyCards(_KingdomProfile p) =>
      p.attackCards.map((c) => c.name).take(3).toList();

  // ===========================================================================
  // Archetype: Trash-to-Victory
  //
  // Triggered by: strong trashers present (trashForBenefit) AND either an
  // alt-victory path or enough remodel/upgrade-style cards to imply a
  // trash-and-gain progression ladder.
  // Threshold: raw >= 4.5
  // ===========================================================================

  static const double _trashVicThreshold = 4.5;
  static const double _trashVicMax       = 12.0;

  StrategyArchetype? _scoreTrashToVictory(_KingdomProfile p) {
    double score = 0;

    for (final c in p.kingdom) {
      if (c.hasTag(CardTag.trashForBenefit)) {
        score += 3.5; // Chapel / Forge
      } else if (c.hasTag(CardTag.trashCards)) {
        score += 1.5;
      }
      if (c.hasTag(CardTag.remodel)) {
        score += 1.2;
      }
      if (c.hasTag(CardTag.altVictory))      score += 1.0;
      if (c.hasTag(CardTag.gainVictory))     score += 0.8;
    }

    if (score < _trashVicThreshold) return null;

    return StrategyArchetype(
      kind:         ArchetypeKind.trashToVictory,
      headline:     _trashVicHeadline(p),
      description:  _trashVicDescription(p),
      tips:         _trashVicTips(p),
      keyCardNames: _trashVicKeyCards(p),
      strength:     (score / _trashVicMax).clamp(0.0, 1.0),
    );
  }

  String _trashVicHeadline(_KingdomProfile p) {
    if (p.kingdom.any((c) => c.hasTag(CardTag.remodel))) {
      return 'Upgrade / Remodel Chain';
    }
    return 'Trash-to-Victory';
  }

  String _trashVicDescription(_KingdomProfile p) {
    final trashers = p.trashCards.map((c) => c.name).join(' and ');

    final remodelCards = p.kingdom.where((c) => c.hasTag(CardTag.remodel)).toList();
    final remodelNote  = remodelCards.isEmpty
        ? ''
        : ' ${remodelCards.map((c) => c.name).join(' and ')} can upgrade '
          'Copper → Silver → Gold or Estate → Duchy → Province — '
          'a slow but inevitably powerful progression.';

    return 'Aggressive trashing with $trashers strips starting Copper and '
        'Estates from your deck, leaving only high-value cards.$remodelNote '
        'A lean 5-card deck cycles 2–3× faster than a bloated one — the '
        'tempo advantage alone often decides the game.';
  }

  List<String> _trashVicTips(_KingdomProfile p) {
    final tips = <String>[];

    final mainTrasher = p.trashCards.isNotEmpty
        ? p.trashCards.firstWhere(
            (c) => c.hasTag(CardTag.trashForBenefit),
            orElse: () => p.trashCards.first,
          )
        : null;

    if (mainTrasher != null) {
      tips.add('Open ${mainTrasher.name} / Silver. Use ${mainTrasher.name} '
               'aggressively in the first 3–4 reshuffles — trash as many '
               'Coppers and Estates as you can before pivoting to buys.');
    }

    // Remodelspecific
    final remodelCards = p.kingdom.where((c) => c.hasTag(CardTag.remodel)).toList();
    if (remodelCards.isNotEmpty) {
      tips.add('${remodelCards.first.name} upgrades cards by \$2 in cost. '
               'Upgrade Estates → useful \$4 cards, then trash those → Provinces '
               'in the late game for a devastating points burst.');
    }

    // Alt VP interaction
    final altVPs = p.kingdom.where((c) => c.hasTag(CardTag.altVictory)).toList();
    if (altVPs.isNotEmpty) {
      tips.add('${altVPs.first.name} offers an alternative point source — '
               'evaluate whether racing it beats the Province pile outright.');
    }

    tips.add('Resist buying engine pieces until you have fewer than 8 cards '
             'in your deck. A thin deck + Silver is often stronger than a '
             'thick engine mid-build.');

    tips.add('Watch your opponent\'s trash pile. If they are also trashing, '
             'the game can end faster than expected — keep an eye on three-pile risk.');

    return tips;
  }

  List<String> _trashVicKeyCards(_KingdomProfile p) {
    return <String>{
      ...p.trashCards.map((c) => c.name),
      ...p.kingdom.where((c) => c.hasTag(CardTag.remodel)).map((c) => c.name),
    }.take(4).toList();
  }

  // ===========================================================================
  // Archetype: Alt-Victory
  //
  // Triggered by: 1+ card with [altVictory] tag.
  // Threshold: raw >= 3.0
  // ===========================================================================

  static const double _altVicThreshold = 3.0;
  static const double _altVicMax       = 8.0;

  StrategyArchetype? _scoreAltVictory(_KingdomProfile p) {
    final altCards = p.kingdom.where((c) => c.hasTag(CardTag.altVictory)).toList();
    if (altCards.isEmpty) return null;

    double score = altCards.length * 3.0;

    // Extra weight for alt-VP that synergise with other kingdom cards
    for (final alt in altCards) {
      // Gardens rewards large decks — more gainers = higher score
      if (alt.id == 'gardens') {
        final gainers = p.kingdom.where((c) => c.hasTag(CardTag.gainCard)).length;
        score += gainers * 0.5;
      }
      // Duke rewards Duchies — more coin = easier to buy Duchies
      if (alt.id == 'duke') {
        score += p.kingdom.where((c) => c.hasTag(CardTag.plusCoin)).length * 0.4;
      }
    }

    if (score < _altVicThreshold) return null;

    return StrategyArchetype(
      kind:         ArchetypeKind.altVictory,
      headline:     _altVicHeadline(altCards),
      description:  _altVicDescription(p, altCards),
      tips:         _altVicTips(p, altCards),
      keyCardNames: altCards.map((c) => c.name).toList(),
      strength:     (score / _altVicMax).clamp(0.0, 1.0),
    );
  }

  String _altVicHeadline(List<DominionCard> altCards) {
    if (altCards.length >= 2) return 'Multi-Path Alt-Victory';
    return 'Alt-Victory: ${altCards.first.name}';
  }

  String _altVicDescription(_KingdomProfile p, List<DominionCard> altCards) {
    final paths = altCards.map((c) {
      if (c.id == 'gardens')  return '${c.name} (1VP per 10 cards — buy lots)';
      if (c.id == 'duke')     return '${c.name} (1VP per Duchy — stack Duchies early)';
      if (c.id == 'harem')    return '${c.name} (\$2 + 2VP — strong economy)';
      if (c.id == 'nobles')   return '${c.name} (flexible +Cards or +Actions + 2VP)';
      if (c.id == 'mill')     return '${c.name} (1VP + situational +\$2)';
      if (c.id == 'island')   return '${c.name} (set aside 2VP, removes junk from deck)';
      return c.name;
    }).join('; ');

    return 'Non-Province victory paths are available: $paths. '
        'These create a fork your opponents must respond to — '
        'if they race only Provinces, the alt-VP path may let you '
        'accumulate points faster or on a cheaper budget.';
  }

  List<String> _altVicTips(_KingdomProfile p, List<DominionCard> altCards) {
    final tips = <String>[];

    for (final alt in altCards) {
      if (alt.id == 'gardens') {
        tips.add('Gardens: maximise deck size — buy Workshops, Ironworks, or '
                 'cheap gainers to bloat your count. Every 10th card is 1 VP.');
        tips.add('Do NOT trash cards if going for Gardens. Volume is the strategy.');
      }
      if (alt.id == 'duke') {
        tips.add('Duke + Duchy stack: aim to buy 4–5 Duchies. Each Duchy is '
                 'then worth 3+4=7 VP with 4 Dukes — compare to 4 Provinces (16 VP) '
                 'but Duchies cost only \$5 vs \$8.');
      }
      if (alt.id == 'island') {
        tips.add('Island removes itself AND a card from your deck — '
                 'use it to exile Estates or Coppers for both VP and deck thinning.');
      }
    }

    tips.add('Force your opponents to split attention between blocking your '
             'alt-VP and buying their own Provinces. Announcing the strategy '
             'early (buying 2 copies quickly) escalates the pressure.');

    tips.add('Know when to abandon the alt path. If Provinces are going fast '
             'and your alt-VP count lags, switch to Province buying — '
             'do not be stubborn about the strategy.');

    return tips;
  }

  // ===========================================================================
  // Archetype: Mirror Match
  //
  // Triggered by: 2+ attacks AND 1+ reaction card.
  // Both sides will race to attacks while the Reaction creates a meaningful
  // decision about hand-space vs. protection.
  // Threshold: raw >= 5.0
  // ===========================================================================

  static const double _mirrorThreshold = 5.0;
  static const double _mirrorMax       = 10.0;

  StrategyArchetype? _scoreMirrorMatch(_KingdomProfile p) {
    if (p.attackCount < 2 || p.reactionCount < 1) return null;

    final score = (p.attackCount * 1.5) + (p.reactionCount * 2.0) +
                  (p.discardAttackCount * 0.5);

    if (score < _mirrorThreshold) return null;

    final attackNames   = p.attackCards.map((c) => c.name).join(', ');
    final reactionNames = p.kingdom
        .where((c) => c.hasTag(CardTag.reaction))
        .map((c) => c.name)
        .join(', ');

    return StrategyArchetype(
      kind:         ArchetypeKind.mirrorMatch,
      headline:     'Mirror Match',
      description:  'With $attackNames available and $reactionNames providing '
                    'defence, this kingdom rewards the player who resolves the '
                    '"attack vs. react" tension most efficiently. Holding a '
                    'Reaction in hand is free insurance — the question is how '
                    'many Action slots it costs you.',
      tips: [
        'Buy one copy of $reactionNames early — it pays for itself if your '
        'opponent attacks twice or more.',
        'Attackers win if the Reaction player wastes too many turns building '
        'defence. Match attack buys with your opponent to avoid falling behind.',
        'In a mirror, the first player to pivot from attacks to Provinces usually '
        'wins — do not over-commit to attacking past the mid-game.',
        'If attacks cost more Actions than they return economy, pivot earlier '
        'than instinct suggests.',
      ],
      keyCardNames: [
        ...p.attackCards.map((c) => c.name).take(2),
        ...p.kingdom.where((c) => c.hasTag(CardTag.reaction)).map((c) => c.name),
      ],
      strength: (score / _mirrorMax).clamp(0.0, 1.0),
    );
  }
}

// =============================================================================
// _KingdomProfile — pre-computed lookups so each scorer avoids repeated scans
// =============================================================================

class _KingdomProfile {
  final List<DominionCard> kingdom;

  late final Map<CardTag, List<DominionCard>> _byTag;

  _KingdomProfile(this.kingdom) {
    _byTag = {};
    for (final tag in CardTag.values) {
      _byTag[tag] = kingdom.where((c) => c.hasTag(tag)).toList();
    }
  }

  List<DominionCard> cardsWithTag(CardTag tag) => _byTag[tag]!;

  // ── Action chaining ────────────────────────────────────────────────────────
  int get villageCount     => cardsWithTag(CardTag.villageEffect).length;
  int get plusActionCount  => cardsWithTag(CardTag.plusAction).length +
                              cardsWithTag(CardTag.plusTwoActions).length;

  // ── Draw ───────────────────────────────────────────────────────────────────
  List<DominionCard> get drawCards =>
      kingdom.where((c) => c.hasTag(CardTag.plusCard) || c.hasTag(CardTag.drawToX))
             .toList();
  int get drawCount => drawCards.length;

  /// Draw cards that do NOT also give +Actions (terminals).
  int get terminalDrawCount =>
      kingdom.where((c) =>
          (c.hasTag(CardTag.plusCard) || c.hasTag(CardTag.drawToX)) &&
          !c.hasTag(CardTag.plusAction) &&
          !c.hasTag(CardTag.villageEffect)).length;

  // ── Sifting ────────────────────────────────────────────────────────────────
  List<DominionCard> get siftingCards => cardsWithTag(CardTag.sifting);

  // ── Trashing ───────────────────────────────────────────────────────────────
  List<DominionCard> get trashCards =>
      kingdom.where((c) =>
          c.hasTag(CardTag.trashCards) || c.hasTag(CardTag.trashForBenefit))
             .toList();
  int get trashCount => trashCards.length;

  // ── Attacks ────────────────────────────────────────────────────────────────
  List<DominionCard> get attackCards =>
      kingdom.where((c) => c.isAttack).toList();
  int get attackCount        => attackCards.length;
  int get discardAttackCount => cardsWithTag(CardTag.discard).length;
  int get curseAttackCount   => cardsWithTag(CardTag.curse).length;
  int get junkingAttackCount => cardsWithTag(CardTag.junking).length;
  int get topdeckAttackCount => attackCards.where((c) => c.hasTag(CardTag.topdeck)).length;

  // ── Reactions ─────────────────────────────────────────────────────────────
  int get reactionCount => cardsWithTag(CardTag.reaction).length;
}
