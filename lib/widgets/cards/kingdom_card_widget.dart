import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/card_tag.dart';
import '../../models/card_type.dart';
import '../../models/kingdom_card.dart';
import '../../providers/card_data_providers.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';

class KingdomCardWidget extends StatelessWidget {
  final KingdomCard card;
  final List<KingdomCard> splitPileCards;
  final int index; // 1-based display number

  const KingdomCardWidget({
    super.key,
    required this.card,
    this.splitPileCards = const [],
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(card.types);
    final isSplit = splitPileCards.isNotEmpty;
    final splitLabel = splitPileCards.map((c) => c.name).join(' / ');

    return Semantics(
      label:
          '${card.name}${isSplit ? ' / $splitLabel' : ''}, ${card.typeString}. Cost: ${card.costString}. Tap for details.',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _showDetail(context, accent),
          borderRadius: BorderRadius.circular(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Multi-type cards can blend their type colors vertically.
                  _AccentStrip(types: card.types),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name row + cost badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  card.name,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CostBadge(cost: card.costString),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Type pills
                          _TypePills(types: card.types),

                          const SizedBox(height: 6),

                          // Card text (truncated)
                          Expanded(
                            child: Text(
                              card.text,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                                height: 1.35,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Split pile partner label
                          if (isSplit) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.layers_rounded,
                                    size: 10,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '+ $splitLabel',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Footer: expansion + tap hint
                          Row(
                            children: [
                              ExpansionBadge(
                                  expansion: card.expansion, fontSize: 11),
                              const Spacer(),
                              Icon(Icons.open_in_full_rounded,
                                  size: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ],
                          ),
                        ],
                      ), // Column
                    ), // Padding
                  ), // Expanded
                ], // Row.children
              ), // Row
            ), // Container
          ), // ClipRRect
        ), // InkWell
      ), // Material
    ); // Semantics
  }

  void _showDetail(BuildContext context, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardDetailSheet(
        card: card,
        splitPileCards: splitPileCards,
        accent: accent,
      ),
    );
  }

  // ── Type → accent colour ──────────────────────────────────────────────────
  // Priority matches the game's visual hierarchy: curse > attack > reaction >
  // duration > treasure > victory > night > action (default).
  // Internal-accessible so _ChainStep can reuse it for upgrade card sheets.
  static Color _accentColor(List<CardType> types) {
    final accentTypes = _accentTypesInPriorityOrder(types);
    return _typeAccentColor(accentTypes.firstOrNull ?? CardType.action);
  }

  static List<Color> _accentStripColors(List<CardType> types) {
    final accentTypes = _accentTypesInDisplayOrder(types);
    if (accentTypes.length > 1) {
      accentTypes.removeWhere((t) => t == CardType.action);
    }
    final colors =
        accentTypes.map(_typeAccentColor).fold<List<Color>>([], (list, color) {
      if (!list.contains(color)) list.add(color);
      return list;
    });
    return colors.isEmpty ? [_typeAccentColor(CardType.action)] : colors;
  }

  static List<CardType> _accentTypesInDisplayOrder(List<CardType> types) {
    return types.where((t) => t.isKingdomCard).toList();
  }

  static List<CardType> _accentTypesInPriorityOrder(List<CardType> types) {
    final priority = [
      CardType.curse,
      CardType.attack,
      CardType.reaction,
      CardType.duration,
      CardType.treasure,
      CardType.victory,
      CardType.night,
      CardType.action,
    ];
    return priority.where(types.contains).toList();
  }

  static Color _typeAccentColor(CardType type) {
    switch (type) {
      case CardType.curse:
        return const Color(0xFF9C27B0);
      case CardType.attack:
        return const Color(0xFFCF3C3C);
      case CardType.reaction:
        return const Color(0xFF1976D2);
      case CardType.duration:
        return const Color(0xFFE65100);
      case CardType.treasure:
        return const Color(0xFFFFB300);
      case CardType.victory:
        return const Color(0xFF388E3C);
      case CardType.night:
        return const Color(0xFF5C35CC);
      default:
        return const Color(0xFF546E7A);
    }
  }
}

class _AccentStrip extends StatelessWidget {
  final List<CardType> types;

  const _AccentStrip({required this.types});

  @override
  Widget build(BuildContext context) {
    final colors = KingdomCardWidget._accentStripColors(types);
    final decoration = colors.length == 1
        ? BoxDecoration(color: colors.first)
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          );

    return Container(width: 3, decoration: decoration);
  }
}

// ── Cost badge (coin circle / debt hexagon) ───────────────────────────────

class _CostBadge extends StatelessWidget {
  final String cost;
  const _CostBadge({required this.cost});

  // Pure-debt cards end with 'D' and have no '$' prefix (e.g. "4D").
  bool get _isDebt => cost.endsWith('D') && !cost.startsWith(r'$');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (_isDebt) {
      return Container(
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.debtBadgeFillDark : AppColors.debtBadgeFill,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark
                ? AppColors.debtBadgeBorderDark
                : AppColors.debtBadgeBorder,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          cost,
          style: TextStyle(
            color:
                isDark ? AppColors.debtBadgeTextDark : AppColors.debtBadgeText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    // Standard coin badge
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary,
        border: Border.all(color: cs.primary.withValues(alpha: 0.7)),
      ),
      alignment: Alignment.center,
      child: Text(
        cost,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Detail sheet cost badge (larger, same debt logic) ─────────────────────

class _DetailCostBadge extends StatelessWidget {
  final String costString;
  const _DetailCostBadge({required this.costString});

  bool get _isDebt => costString.endsWith('D') && !costString.startsWith(r'$');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (_isDebt) {
      return Container(
        constraints: const BoxConstraints(minWidth: 40),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.debtBadgeFillDark : AppColors.debtBadgeFill,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isDark
                ? AppColors.debtBadgeBorderDark
                : AppColors.debtBadgeBorder,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          costString,
          style: TextStyle(
            color:
                isDark ? AppColors.debtBadgeTextDark : AppColors.debtBadgeText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary,
        border:
            Border.all(color: cs.primary.withValues(alpha: 0.7), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        costString,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Type pills strip ─────────────────────────────────────────────────────────

class _TypePills extends StatelessWidget {
  final List<CardType> types;
  const _TypePills({required this.types});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: types
          .where((t) => t.isKingdomCard) // skip non-kingdom type markers
          .map((t) {
        final color = _typeColor(t);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            t.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  static Color _typeColor(CardType t) {
    switch (t) {
      case CardType.action:
        return const Color(0xFF90A4AE);
      case CardType.treasure:
        return const Color(0xFFFFB300);
      case CardType.victory:
        return const Color(0xFF66BB6A);
      case CardType.curse:
        return const Color(0xFFCE93D8);
      case CardType.attack:
        return const Color(0xFFEF9A9A);
      case CardType.reaction:
        return const Color(0xFF64B5F6);
      case CardType.duration:
        return const Color(0xFFFFB74D);
      case CardType.night:
        return const Color(0xFF9575CD);
      case CardType.reserve:
        return const Color(0xFF80CBC4);
      default:
        return const Color(0xFF78909C);
    }
  }
}

// ── Card detail bottom sheet ─────────────────────────────────────────────────

class _CardDetailSheet extends StatelessWidget {
  final KingdomCard card;
  final List<KingdomCard> splitPileCards;
  final Color accent;

  const _CardDetailSheet({
    required this.card,
    this.splitPileCards = const [],
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  // Header: name + cost
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          card.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DetailCostBadge(costString: card.costString),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Types + expansion
                  Row(
                    children: [
                      _TypePills(types: card.types),
                      const Spacer(),
                      ExpansionBadge(expansion: card.expansion, fontSize: 11),
                    ],
                  ),

                  const Divider(height: 24),

                  // Rules text
                  Text(
                    card.text,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Split pile cards
                  if (splitPileCards.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      splitPileCards.length == 1
                          ? 'SPLIT PILE'
                          : 'ROTATING PILE',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      splitPileCards.length == 1
                          ? 'Both halves share one Supply pile.'
                          : 'These cards share one rotating Supply pile.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    for (final pileCard in splitPileCards) ...[
                      _SplitPileCard(card: pileCard),
                      if (pileCard != splitPileCards.last)
                        const SizedBox(height: 8),
                    ],
                  ],

                  // Mixed piles such as Dark Ages Knights
                  if (card.pileCards.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'PILE CARDS',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These cards share this Supply pile.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _PileCards(names: card.pileCards),
                  ],

                  // Traveller/exchange chain
                  if (card.travellerChain.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'EXCHANGE CHAIN',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set these cards aside before play.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _TravellerChain(
                      base: card,
                      chain: card.travellerChain,
                    ),
                  ],

                  // Tags section
                  if (card.tags.isNotEmpty) ...[
                    Text(
                      'MECHANICS',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: card.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  border: Border.all(
                                      color: accent.withValues(alpha: 0.35)),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  tag.displayName,
                                  style: TextStyle(
                                    color: accent.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Split pile card ────────────────────────────────────────────────────────

class _SplitPileCard extends StatelessWidget {
  final KingdomCard card;
  const _SplitPileCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final accent = KingdomCardWidget._accentColor(card.types);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded,
                  size: 13, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.name,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CostBadge(cost: card.costString),
            ],
          ),
          const SizedBox(height: 6),
          _TypePills(types: card.types),
          const SizedBox(height: 8),
          Text(
            card.text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PileCards extends ConsumerWidget {
  final List<String> names;

  const _PileCards({required this.names});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allCardsProvider);
    final cardByName = allAsync.whenData((all) {
      return {for (final c in all) c.name.toLowerCase(): c};
    });

    return Column(
      children: [
        for (final name in names)
          _PileCardRow(
            name: name,
            card: cardByName.whenOrNull(
              data: (m) => m[name.toLowerCase()],
            ),
          ),
      ],
    );
  }
}

class _PileCardRow extends StatelessWidget {
  final String name;
  final KingdomCard? card;

  const _PileCardRow({required this.name, required this.card});

  @override
  Widget build(BuildContext context) {
    final accent = card == null
        ? Theme.of(context).colorScheme.outline
        : KingdomCardWidget._accentColor(card!.types);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: card == null ? null : () => _showDetail(context),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(Icons.style_rounded, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (card != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          card!.text,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (card != null)
                  Icon(Icons.open_in_full_rounded,
                      size: 11, color: accent.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    if (card == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardDetailSheet(
        card: card!,
        accent: KingdomCardWidget._accentColor(card!.types),
      ),
    );
  }
}

// ── Traveller/exchange chain ───────────────────────────────────────────────

/// Displays the full set-aside chain for [base], each step tappable to reveal
/// the chained card's rules text. Uses [allCardsProvider] to look up text for
/// intermediate cards when they are present in the data file.
class _TravellerChain extends ConsumerWidget {
  final KingdomCard base;
  final List<String> chain;

  const _TravellerChain({required this.base, required this.chain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allCardsProvider);

    // Build lookup map: lowercase name → card.
    final cardByName = allAsync.whenData((all) {
      return {for (final c in all) c.name.toLowerCase(): c};
    });

    return Column(
      children: [
        for (var i = 0; i < chain.length; i++) ...[
          _ChainStep(
            name: chain[i],
            // Resolve the card object so we can show its text.
            card: cardByName.whenOrNull(
              data: (m) => m[chain[i].toLowerCase()],
            ),
            isBase: false,
            isFinal: i == chain.length - 1,
            accent: _accentColor(i + 1, chain.length + 1),
          ),
          if (i < chain.length - 1)
            Builder(builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    Container(width: 2, height: 12, color: cs.outlineVariant),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_downward_rounded,
                        size: 11, color: cs.onSurfaceVariant),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }

  static Color _accentColor(int index, int total) {
    if (index == 0) return const Color(0xFF26C6DA); // teal – base
    if (index == total - 1) return const Color(0xFFC49A0A); // gold – top
    return const Color(0xFF7D8590); // dim – middle
  }
}

class _ChainStep extends StatelessWidget {
  final String name;
  final KingdomCard? card; // null while allCardsProvider is loading
  final bool isBase;
  final bool isFinal;
  final Color accent;

  const _ChainStep({
    required this.name,
    required this.card,
    required this.isBase,
    required this.isFinal,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: card != null ? '$name: ${card!.text}' : name,
      button: card != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: card != null ? () => _showUpgradeDetail(context) : null,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isBase || isFinal ? 0.08 : 0.04),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                Icon(
                  isFinal
                      ? Icons.star_rounded
                      : isBase
                          ? Icons.person_rounded
                          : Icons.upgrade_rounded,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: isBase || isFinal
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (card != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          card!.text,
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.65),
                            fontSize: 11,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (isBase)
                  _Badge(label: 'start', color: accent)
                else if (isFinal)
                  _Badge(label: 'top', color: accent)
                else if (card != null)
                  Icon(Icons.open_in_full_rounded,
                      size: 11, color: accent.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ), // InkWell
      ), // Material
    );
  }

  void _showUpgradeDetail(BuildContext context) {
    if (card == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardDetailSheet(
        card: card!,
        accent: KingdomCardWidget._accentColor(card!.types),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );
}
