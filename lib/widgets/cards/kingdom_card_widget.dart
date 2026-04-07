import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/card_tag.dart';
import '../../models/card_type.dart';
import '../../models/dominion_card.dart';
import '../../providers/card_data_providers.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';

class KingdomCardWidget extends StatelessWidget {
  final DominionCard card;
  final int          index; // 1-based display number

  const KingdomCardWidget({
    super.key,
    required this.card,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(card.types);

    return Semantics(
      label:  '${card.name}, ${card.typeString}. Cost: ${card.costString}. Tap for details.',
      button: true,
      excludeSemantics: true,
      child: Material(
      color:        AppColors.cardSurface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap:        () => _showDetail(context, accent),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color:  AppColors.cardSurface,
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured left-accent strip replaces the BorderSide approach
              Container(width: 3, color: accent),
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
                      style: const TextStyle(
                        color:      AppColors.parchment,
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        height:     1.2,
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
                  style: const TextStyle(
                    color:    AppColors.parchmentDim,
                    fontSize: 12,
                    height:   1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 6),

              // Footer: expansion + tap hint
              Row(
                children: [
                  ExpansionBadge(expansion: card.expansion, fontSize: 11),
                  const Spacer(),
                  const Icon(Icons.open_in_full_rounded,
                      size: 11, color: AppColors.parchmentDim),
                ],
              ),
            ],
          ),        // Column
        ),          // Padding
      ),            // Expanded
    ],              // Row.children
  ),               // Row
),                 // Container
),                 // ClipRRect
),                 // InkWell
),                 // Material
);                 // Semantics
  }

  void _showDetail(BuildContext context, Color accent) {
    showModalBottomSheet<void>(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => _CardDetailSheet(card: card, accent: accent),
    );
  }

  // ── Type → accent colour ──────────────────────────────────────────────────
  // Priority matches Dominion's visual hierarchy: curse > attack > reaction >
  // duration > treasure > victory > night > action (default).
  // Internal-accessible so _ChainStep can reuse it for upgrade card sheets.
  static Color _accentColor(List<CardType> types) {
    if (types.contains(CardType.curse))    return const Color(0xFF9C27B0);
    if (types.contains(CardType.attack))   return const Color(0xFFCF3C3C);
    if (types.contains(CardType.reaction)) return const Color(0xFF1976D2);
    if (types.contains(CardType.duration)) return const Color(0xFFE65100);
    if (types.contains(CardType.treasure)) return const Color(0xFFFFB300);
    if (types.contains(CardType.victory))  return const Color(0xFF388E3C);
    if (types.contains(CardType.night))    return const Color(0xFF5C35CC);
    return const Color(0xFF546E7A); // action
  }
}

// ── Cost badge (coin circle) ───────────────────────────────────────────────

class _CostBadge extends StatelessWidget {
  final String cost;
  const _CostBadge({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:  const BoxConstraints(minWidth: 26),
      height:       26,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.goldDark,
      ),
      alignment: Alignment.center,
      child: Text(
        cost,
        style: const TextStyle(
          color:      Colors.black,
          fontSize:   11,
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
      spacing:    4,
      runSpacing: 3,
      children: types
          .where((t) => t.isKingdomCard) // skip non-kingdom type markers
          .map((t) {
            final color = _typeColor(t);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.15),
                border:       Border.all(color: color.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                t.displayName,
                style: TextStyle(
                  color:      color,
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          })
          .toList(),
    );
  }

  static Color _typeColor(CardType t) {
    switch (t) {
      case CardType.action:    return const Color(0xFF90A4AE);
      case CardType.treasure:  return const Color(0xFFFFB300);
      case CardType.victory:   return const Color(0xFF66BB6A);
      case CardType.curse:     return const Color(0xFFCE93D8);
      case CardType.attack:    return const Color(0xFFEF9A9A);
      case CardType.reaction:  return const Color(0xFF64B5F6);
      case CardType.duration:  return const Color(0xFFFFB74D);
      case CardType.night:     return const Color(0xFF9575CD);
      case CardType.reserve:   return const Color(0xFF80CBC4);
      default:                 return AppColors.parchmentDim;
    }
  }
}

// ── Card detail bottom sheet ─────────────────────────────────────────────────

class _CardDetailSheet extends StatelessWidget {
  final DominionCard card;
  final Color        accent;

  const _CardDetailSheet({required this.card, required this.accent});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.35,
      maxChildSize:     0.85,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border:       Border(top: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width:  40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.divider,
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
                          style: const TextStyle(
                            color:      AppColors.parchment,
                            fontSize:   22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldDark,
                          border: Border.all(
                              color: AppColors.gold, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          card.costString,
                          style: const TextStyle(
                            color:      Colors.black,
                            fontSize:   14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
                    style: const TextStyle(
                      color:    AppColors.parchment,
                      fontSize: 15,
                      height:   1.55,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Traveller upgrade chain
                  if (card.travellerChain.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'TRAVELLER CHAIN',
                      style: TextStyle(
                        color:         AppColors.gold,
                        fontSize:      10,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set these cards aside before play.',
                      style: TextStyle(
                          color: AppColors.parchmentDim, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _TravellerChain(
                      base:  card,
                      chain: card.travellerChain,
                    ),
                  ],

                  // Tags section
                  if (card.tags.isNotEmpty) ...[
                    const Text(
                      'MECHANICS',
                      style: TextStyle(
                        color:         AppColors.gold,
                        fontSize:      10,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing:    6,
                      runSpacing: 6,
                      children: card.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:        accent.withValues(alpha: 0.1),
                                  border:       Border.all(
                                      color: accent.withValues(alpha: 0.35)),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  tag.displayName,
                                  style: TextStyle(
                                    color:    accent.withValues(alpha: 0.85),
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

// ── Traveller upgrade chain ────────────────────────────────────────────────

/// Displays the full traveller chain for [base], each step tappable to reveal
/// the upgrade card's rules text. Uses [allCardsProvider] to look up text for
/// the intermediate upgrade cards (Treasure Hunter, Warrior, etc.).
class _TravellerChain extends ConsumerWidget {
  final DominionCard base;
  final List<String> chain;

  const _TravellerChain({required this.base, required this.chain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allCardsProvider);

    // Build lookup map: lowercase name → card.
    final cardByName = allAsync.whenData((all) {
      return {for (final c in all) c.name.toLowerCase(): c};
    });

    // Full step list: [base, ...upgrades]
    final names = [base.name, ...chain];

    return Column(
      children: [
        for (var i = 0; i < names.length; i++) ...[
          _ChainStep(
            name:     names[i],
            // Resolve the card object so we can show its text.
            card:     i == 0
                ? base
                : cardByName.whenOrNull(
                    data: (m) => m[names[i].toLowerCase()],
                  ),
            isBase:   i == 0,
            isFinal:  i == names.length - 1,
            accent:   _accentColor(i, names.length),
          ),
          if (i < names.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Row(
                children: [
                  Container(width: 2, height: 12, color: AppColors.divider),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_downward_rounded,
                      size: 11, color: AppColors.parchmentDim),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static Color _accentColor(int index, int total) {
    if (index == 0)          return const Color(0xFF26C6DA); // teal – base
    if (index == total - 1)  return AppColors.gold;          // gold – top
    return AppColors.parchmentDim;                           // dim – middle
  }
}

class _ChainStep extends StatelessWidget {
  final String        name;
  final DominionCard? card;   // null while allCardsProvider is loading
  final bool          isBase;
  final bool          isFinal;
  final Color         accent;

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
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
        onTap:        card != null ? () => _showUpgradeDetail(context) : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        accent.withValues(alpha: isBase || isFinal ? 0.08 : 0.04),
            border:       Border.all(color: accent.withValues(alpha: 0.3)),
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
                size:  14,
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
                        color:      accent,
                        fontSize:   13,
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
                          color:    accent.withValues(alpha: 0.65),
                          fontSize: 11,
                          height:   1.35,
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
        ),  // InkWell
      ),    // Material
    );
  }

  void _showUpgradeDetail(BuildContext context) {
    if (card == null) return;
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CardDetailSheet(
        card:   card!,
        accent: KingdomCardWidget._accentColor(card!.types),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11)),
  );
}
