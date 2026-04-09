import 'package:flutter/material.dart';

import '../../models/strategy_archetype.dart';
import '../../utils/archetype_utils.dart';

class ArchetypeCard extends StatefulWidget {
  final StrategyArchetype archetype;
  final bool              isPrimary;

  const ArchetypeCard({
    super.key,
    required this.archetype,
    this.isPrimary = false,
  });

  @override
  State<ArchetypeCard> createState() => _ArchetypeCardState();
}

class _ArchetypeCardState extends State<ArchetypeCard> {
  bool   _tipsExpanded      = false;
  double _animatedStrength  = 0;

  @override
  void initState() {
    super.initState();
    // Defer so AnimatedContainer actually animates from 0 → final value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _animatedStrength = widget.archetype.strength);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ArchetypeUtils.color(widget.archetype.kind);
    final icon  = ArchetypeUtils.icon(widget.archetype.kind);
    final pct   = (widget.archetype.strength * 100).round();
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color:        cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(
          color: widget.isPrimary ? color : cs.outlineVariant,
          width: widget.isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color:        color.withValues(alpha: widget.isPrimary ? 0.18 : 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 12),

                // Title + kind label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isPrimary)
                        Text(
                          'PRIMARY STRATEGY',
                          style: TextStyle(
                            color:         color,
                            fontSize:      11,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      Text(
                        widget.archetype.headline,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: cs.onSurface,
                          fontSize: widget.isPrimary ? 17 : 15,
                        ),
                      ),
                    ],
                  ),
                ),

                // Strength badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      color:      color,
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Strength bar (animates from 0 on first render) ─────────────
          LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                Container(height: 3, color: cs.outlineVariant),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve:    Curves.easeOut,
                  height:   3,
                  width:    constraints.maxWidth * _animatedStrength,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.7),
                        color,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  widget.archetype.description,
                  style: TextStyle(
                    color:  cs.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),

                // Key cards
                if (widget.archetype.keyCardNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'KEY CARDS',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing:    5,
                    runSpacing: 5,
                    children: widget.archetype.keyCardNames
                        .map((name) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color:        color.withValues(alpha: 0.12),
                                border:       Border.all(
                                    color: color.withValues(alpha: 0.35)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color:      color.withValues(alpha: 0.9),
                                  fontSize:   11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],

                // Tips (collapsible)
                if (widget.archetype.tips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: _tipsExpanded ? 'Collapse tips' : 'Expand tips',
                    button: true,
                    child: InkWell(
                    onTap: () =>
                        setState(() => _tipsExpanded = !_tipsExpanded),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            'TIPS',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns:    _tipsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: cs.primary,
                              size:  16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),  // Semantics
                  AnimatedCrossFade(
                    duration:     const Duration(milliseconds: 250),
                    crossFadeState: _tipsExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild:  const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 4),
                        ...widget.archetype.tips.asMap().entries.map(
                          (e) => _TipRow(
                            number: e.key + 1,
                            text:   e.value,
                            color:  color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// ── Numbered tip row ───────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final int    number;
  final String text;
  final Color  color;

  const _TipRow({
    required this.number,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:    Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height:   1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
