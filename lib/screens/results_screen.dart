import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_tag.dart';
import '../models/setup_result.dart';
import '../models/strategy_archetype.dart';
import '../providers/generation_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/cards/archetype_card.dart';
import '../widgets/cards/kingdom_card_widget.dart';
import '../widgets/common/section_header.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result        = ref.watch(setupResultProvider);
    final status        = ref.watch(generationStatusProvider);
    final isRegenerating = status == GenerationStatus.loading;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kingdom')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _ResultsAppBar(
        result:          result,
        isRegenerating:  isRegenerating,
        onRegenerate: () => _regenerate(context, ref),
        onCopy:       () => _copyKingdom(context, result),
      ),
      body: isRegenerating
          ? const _RegeneratingOverlay()
          : _ResultsBody(result: result),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final success = await generateKingdom(ref);
    if (!success && context.mounted) {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text(error),
          backgroundColor: AppColors.errorRed,
          behavior:        SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyKingdom(BuildContext context, SetupResult result) {
    final lines = result.kingdomCards
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.name} (${e.value.costString})')
        .join('\n');
    Clipboard.setData(ClipboardData(text: lines));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:  Text('Kingdom copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────

class _ResultsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final SetupResult  result;
  final bool         isRegenerating;
  final VoidCallback onRegenerate;
  final VoidCallback onCopy;

  const _ResultsAppBar({
    required this.result,
    required this.isRegenerating,
    required this.onRegenerate,
    required this.onCopy,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final expansionCount = result.kingdomCards
        .map((c) => c.expansion)
        .toSet()
        .length;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Kingdom Board',
              style: TextStyle(
                color:      AppColors.parchment,
                fontSize:   17,
                fontWeight: FontWeight.w700,
              )),
          Text(
            '10 cards · $expansionCount expansion${expansionCount == 1 ? '' : 's'}',
            style: TextStyle(
              color:    AppColors.gold.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        // Copy kingdom list
        IconButton(
          tooltip:  'Copy kingdom list',
          onPressed: isRegenerating ? null : onCopy,
          icon: const Icon(Icons.copy_rounded, color: AppColors.parchmentDim),
        ),
        // Regenerate
        IconButton(
          tooltip:  'Regenerate kingdom',
          onPressed: isRegenerating ? null : onRegenerate,
          icon: isRegenerating
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.gold),
                  ),
                )
              : const Icon(Icons.casino_rounded, color: AppColors.gold),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Regenerating overlay ───────────────────────────────────────────────────

class _RegeneratingOverlay extends StatelessWidget {
  const _RegeneratingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.gold),
          ),
          SizedBox(height: 20),
          Text('Drawing a new kingdom…',
              style: TextStyle(color: AppColors.parchmentDim)),
        ],
      ),
    );
  }
}

// ── Main scrollable body ───────────────────────────────────────────────────

class _ResultsBody extends StatelessWidget {
  final SetupResult result;
  const _ResultsBody({required this.result});

  @override
  Widget build(BuildContext context) {
    // Key includes generatedAt so cards re-animate on each regeneration.
    final genKey = result.generatedAt.millisecondsSinceEpoch;

    return CustomScrollView(
      slivers: [
        // ── Archetype summary banner ──────────────────────────────────────
        if (result.archetypes.isNotEmpty)
          SliverToBoxAdapter(
            child: _ArchetypeBanner(result: result),
          ),

        // ── Kingdom board header ──────────────────────────────────────────
        const SliverToBoxAdapter(
          child: SectionHeader(
            title:    'Kingdom Board',
            subtitle: 'Tap a card to see its full rules text.',
          ),
        ),

        // ── 10-card grid (staggered entrance) ────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _StaggeredEntry(
                key:   ValueKey('${genKey}_$i'),
                index: i,
                child: KingdomCardWidget(
                  card:  result.kingdomCards[i],
                  index: i + 1,
                ),
              ),
              childCount: result.kingdomCards.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   2,
              mainAxisExtent:   168,
              crossAxisSpacing: 8,
              mainAxisSpacing:  8,
            ),
          ),
        ),

        // ── Setup notes ───────────────────────────────────────────────────
        if (result.setupNotes.isNotEmpty)
          SliverToBoxAdapter(
            child: _SetupNotesSection(notes: result.setupNotes),
          ),

        // ── Strategy guide ────────────────────────────────────────────────
        if (result.archetypes.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionHeader(
              title:    'Strategy Guide',
              subtitle: 'Heuristic archetypes detected for this kingdom.',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => ArchetypeCard(
                archetype: result.archetypes[i],
                isPrimary: i == 0,
              ),
              childCount: result.archetypes.length,
            ),
          ),
        ],

        // Bottom padding for home indicator
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Staggered entrance animation ──────────────────────────────────────────

class _StaggeredEntry extends StatefulWidget {
  final int    index;
  final Widget child;

  const _StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<_StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<_StaggeredEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.07),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Stagger: each card starts 50 ms after the previous one.
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Archetype summary banner ───────────────────────────────────────────────

class _ArchetypeBanner extends StatelessWidget {
  final SetupResult result;
  const _ArchetypeBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final primary    = result.archetypes.first;
    final secondaries = result.archetypes.skip(1).toList();

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            AppColors.cardSurface,
            _archetypeColor(primary.kind).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _archetypeColor(primary.kind).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary
          Row(
            children: [
              Icon(
                _archetypeIcon(primary.kind),
                color: _archetypeColor(primary.kind),
                size:  16,
              ),
              const SizedBox(width: 6),
              Text(
                primary.headline,
                style: TextStyle(
                  color:      _archetypeColor(primary.kind),
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const Text(
                'PRIMARY',
                style: TextStyle(
                  color:         AppColors.parchmentDim,
                  fontSize:      9,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Secondary archetypes
          if (secondaries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing:    6,
              runSpacing: 6,
              children: secondaries.map((a) {
                final c = _archetypeColor(a.kind);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        c.withValues(alpha: 0.1),
                    border:       Border.all(color: c.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_archetypeIcon(a.kind), color: c, size: 11),
                      const SizedBox(width: 4),
                      Text(a.headline,
                          style: TextStyle(color: c, fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Stat strip
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _StatStrip(result: result),
        ],
      ),
    );
  }

  static Color _archetypeColor(ArchetypeKind kind) {
    switch (kind) {
      case ArchetypeKind.engineBuilding:    return const Color(0xFF42A5F5);
      case ArchetypeKind.bigMoney:          return const Color(0xFFFFD54F);
      case ArchetypeKind.aggressiveControl: return const Color(0xFFEF5350);
      case ArchetypeKind.trashToVictory:    return const Color(0xFFAB47BC);
      case ArchetypeKind.altVictory:        return const Color(0xFF66BB6A);
      case ArchetypeKind.mirrorMatch:       return const Color(0xFF26C6DA);
    }
  }

  static IconData _archetypeIcon(ArchetypeKind kind) {
    switch (kind) {
      case ArchetypeKind.engineBuilding:    return Icons.hub_rounded;
      case ArchetypeKind.bigMoney:          return Icons.monetization_on_outlined;
      case ArchetypeKind.aggressiveControl: return Icons.local_fire_department_rounded;
      case ArchetypeKind.trashToVictory:    return Icons.delete_sweep_rounded;
      case ArchetypeKind.altVictory:        return Icons.emoji_events_rounded;
      case ArchetypeKind.mirrorMatch:       return Icons.compare_arrows_rounded;
    }
  }
}

// ── Stat strip (attacks / trashing / duration / alt-vp) ───────────────────

class _StatStrip extends StatelessWidget {
  final SetupResult result;
  const _StatStrip({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Stat(
          icon:  Icons.local_fire_department_rounded,
          label: 'Attacks',
          value: result.kingdomCards.where((c) => c.isAttack).length,
          color: const Color(0xFFEF5350),
        ),
        _Stat(
          icon:  Icons.delete_sweep_rounded,
          label: 'Trashers',
          value: result.kingdomCards
              .where((c) =>
                  c.hasTag(CardTag.trashCards) ||
                  c.hasTag(CardTag.trashForBenefit))
              .length,
          color: const Color(0xFFAB47BC),
        ),
        _Stat(
          icon:  Icons.hourglass_empty_rounded,
          label: 'Duration',
          value: result.kingdomCards.where((c) => c.isDuration).length,
          color: const Color(0xFFFFB74D),
        ),
        _Stat(
          icon:  Icons.emoji_events_rounded,
          label: 'Alt-VP',
          value: result.victoryCount,
          color: const Color(0xFF66BB6A),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      value;
  final Color    color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? color : AppColors.divider, size: 18),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            color:      active ? color : AppColors.parchmentDim,
            fontSize:   16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color:    AppColors.parchmentDim,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── Setup notes ────────────────────────────────────────────────────────────

class _SetupNotesSection extends StatelessWidget {
  final List<String> notes;
  const _SetupNotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETUP NOTES',
            style: TextStyle(
              color:         AppColors.gold,
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:        AppColors.gold.withValues(alpha: 0.06),
              border:       Border.all(
                  color: AppColors.goldDark.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: notes.asMap().entries.map((entry) {
                final isLast = entry.key == notes.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.gold, size: 15),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                color:    AppColors.parchmentDim,
                                fontSize: 13,
                                height:   1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 14, endIndent: 14),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
