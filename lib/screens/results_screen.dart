import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_tag.dart';
import '../models/dominion_card.dart';
import '../models/setup_result.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../utils/app_theme.dart';
import '../utils/archetype_utils.dart';
import '../widgets/cards/archetype_card.dart';
import '../widgets/cards/kingdom_card_widget.dart';
import '../widgets/common/section_header.dart';

/// Groups a flat kingdom card list into display slots.
/// Cards sharing a splitPileId collapse into a single (primary, partner) slot.
/// The lower-cost card is the primary (shown on the tile).
List<(DominionCard, DominionCard?)> _splitPileSlots(
    List<DominionCard> cards) {
  final seen    = <String>{};
  final slots   = <(DominionCard, DominionCard?)>[];
  final byPile  = <String, List<DominionCard>>{};

  for (final c in cards) {
    if (c.splitPileId != null) {
      (byPile[c.splitPileId!] ??= []).add(c);
    }
  }

  for (final c in cards) {
    if (c.splitPileId == null) {
      slots.add((c, null));
    } else if (!seen.contains(c.splitPileId)) {
      seen.add(c.splitPileId!);
      final pair    = byPile[c.splitPileId!]!;
      final primary = pair.reduce((a, b) => a.cost <= b.cost ? a : b);
      final partner = pair.firstWhere((x) => x.id != primary.id);
      slots.add((primary, partner));
    }
  }
  return slots;
}

/// Public route builder — shared by ConfigurationScreen and HistorySheet.
Route<void> buildResultsRoute() => PageRouteBuilder<void>(
      pageBuilder:               (_, __, ___) => const ResultsScreen(),
      transitionDuration:        const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result         = ref.watch(setupResultProvider);
    final status         = ref.watch(generationStatusProvider);
    final isRegenerating = status == GenerationStatus.loading;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kingdom')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _ResultsAppBar(
        result:         result,
        isRegenerating: isRegenerating,
        onRegenerate:   () => _regenerate(context, ref),
        onCopy:         () => _copyKingdom(context, result),
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
    final slots = _splitPileSlots(result.kingdomCards);
    final lines = slots
        .asMap()
        .entries
        .map((e) {
          final primary = e.value.$1;
          final partner = e.value.$2;
          final label   = partner != null
              ? '${primary.name} / ${partner.name}'
              : primary.name;
          return '${e.key + 1}. $label (${primary.costString})';
        })
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 18);

  @override
  Widget build(BuildContext context) {
    final expansionCount =
        result.kingdomCards.map((c) => c.expansion).toSet().length;
    final tt = Theme.of(context).textTheme;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize:       MainAxisSize.min,
        children: [
          Text('Kingdom Board', style: tt.titleLarge),
          const SizedBox(height: 2),
          Text(
            '10 cards · $expansionCount expansion${expansionCount == 1 ? '' : 's'}',
            style: tt.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip:   'Copy kingdom list',
          onPressed: isRegenerating ? null : onCopy,
          icon: Icon(Icons.copy_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        IconButton(
          tooltip:   'Regenerate kingdom',
          onPressed: isRegenerating ? null : onRegenerate,
          icon: isRegenerating
              ? SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:  AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                  ),
                )
              : Icon(Icons.casino_rounded,
                  color: Theme.of(context).colorScheme.primary),
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
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 20),
        Text('Drawing a new kingdom…',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

// ── Main scrollable body ───────────────────────────────────────────────────

class _ResultsBody extends ConsumerWidget {
  final SetupResult result;
  const _ResultsBody({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerCount = ref.watch(playerCountProvider);
    final genKey      = result.generatedAt.millisecondsSinceEpoch;

    return CustomScrollView(
      slivers: [
        // ── Archetype summary banner ──────────────────────────────────────
        if (result.archetypes.isNotEmpty)
          SliverToBoxAdapter(child: _ArchetypeBanner(result: result)),

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
              (_, i) {
                final slots   = _splitPileSlots(result.kingdomCards);
                final primary = slots[i].$1;
                final partner = slots[i].$2;
                return _StaggeredEntry(
                  key:   ValueKey('${genKey}_$i'),
                  index: i,
                  child: KingdomCardWidget(
                    card:         primary,
                    splitPartner: partner,
                    index:        i + 1,
                  ),
                );
              },
              childCount: _splitPileSlots(result.kingdomCards).length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   2,
              mainAxisExtent:   180,
              crossAxisSpacing: 8,
              mainAxisSpacing:  8,
            ),
          ),
        ),

        // ── Landscape cards (Events / Landmarks / Projects / Ways / Allies)
        if (result.landscapeCards.isNotEmpty)
          SliverToBoxAdapter(
            child: _LandscapeSection(cards: result.landscapeCards),
          ),

        // ── Setup notes ───────────────────────────────────────────────────
        if (result.setupNotes.isNotEmpty)
          SliverToBoxAdapter(
            child: _SetupNotesSection(notes: result.setupNotes),
          ),

        // ── Random first player ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _RandomFirstPlayer(playerCount: playerCount),
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

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Staggered entrance ─────────────────────────────────────────────────────

class _StaggeredEntry extends StatefulWidget {
  final int    index;
  final Widget child;
  const _StaggeredEntry({super.key, required this.index, required this.child});

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
        vsync: this, duration: const Duration(milliseconds: 380));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child:   SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Landscape section ──────────────────────────────────────────────────────

class _LandscapeSection extends StatelessWidget {
  final List<DominionCard> cards;
  const _LandscapeSection({required this.cards});

  @override
  Widget build(BuildContext context) {
    // Group by type label for display
    final groups = <String, List<DominionCard>>{};
    for (final c in cards) {
      final label = _landscapeLabel(c);
      (groups[label] ??= []).add(c);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'LANDSCAPE CARDS',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Place these above the kingdom supply.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ...groups.entries.map((entry) => _LandscapeGroup(
                label: entry.key,
                cards: entry.value,
              )),
        ],
      ),
    );
  }

  static String _landscapeLabel(DominionCard c) {
    if (c.isEvent)    return 'Events';
    if (c.isLandmark) return 'Landmarks';
    if (c.isProject)  return 'Projects';
    if (c.isWay)      return 'Ways';
    if (c.isAlly)     return 'Allies';
    return 'Landscape';
  }
}

class _LandscapeGroup extends StatelessWidget {
  final String             label;
  final List<DominionCard> cards;
  const _LandscapeGroup({required this.label, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...cards.map((c) => Semantics(
          label: '${c.name}: ${c.text}',
          child: Container(
            margin:     const EdgeInsets.only(bottom: 6),
            padding:    const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color:        Theme.of(context).colorScheme.surfaceContainer,
              border:       Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color:        AppColors.landscapeAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:      Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 3),
                      Text(c.text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Random first player ────────────────────────────────────────────────────

class _RandomFirstPlayer extends StatefulWidget {
  final int playerCount;
  const _RandomFirstPlayer({required this.playerCount});

  @override
  State<_RandomFirstPlayer> createState() => _RandomFirstPlayerState();
}

class _RandomFirstPlayerState extends State<_RandomFirstPlayer> {
  int?  _picked;
  bool  _rolling = false;

  Future<void> _roll() async {
    HapticFeedback.mediumImpact();
    setState(() { _rolling = true; _picked = null; });

    // Quick slot-machine flicker: cycle through values 4×
    for (var i = 0; i < widget.playerCount * 4; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() => _picked = (i % widget.playerCount) + 1);
    }

    // Final pick
    final result = Random().nextInt(widget.playerCount) + 1;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    setState(() { _picked = result; _rolling = false; });
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        padding:    const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surfaceContainer,
          border:       Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Result display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRST PLAYER',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 80),
                    child: _picked == null
                        ? Text(
                            'Tap to pick randomly from ${widget.playerCount} players',
                            key: const ValueKey('prompt'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Text(
                            'Player $_picked goes first!',
                            key: ValueKey(_picked),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color:      _rolling
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Roll button
            Semantics(
              label:  'Pick random first player',
              button: true,
              child: Material(
                color:        Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap:        _rolling ? null : _roll,
                  borderRadius: BorderRadius.circular(10),
                  splashColor:  Colors.black26,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color:        _rolling
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                          : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: _rolling
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:  AlwaysStoppedAnimation(Colors.black),
                            ),
                          )
                        : const Icon(Icons.casino_rounded,
                            color: Colors.black, size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Archetype summary banner ───────────────────────────────────────────────

class _ArchetypeBanner extends StatelessWidget {
  final SetupResult result;
  const _ArchetypeBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final primary     = result.archetypes.first;
    final secondaries = result.archetypes.skip(1).toList();

    return Semantics(
      label: 'Primary strategy: ${primary.headline}. '
             '${secondaries.isNotEmpty ? 'Also: ${secondaries.map((a) => a.headline).join(', ')}.' : ''}',
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainer,
              ArchetypeUtils.color(primary.kind).withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: ArchetypeUtils.color(primary.kind).withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(ArchetypeUtils.icon(primary.kind),
                      color: ArchetypeUtils.color(primary.kind), size: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  primary.headline,
                  style: TextStyle(
                    color:      ArchetypeUtils.color(primary.kind),
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'PRIMARY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            if (secondaries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing:    6,
                runSpacing: 6,
                children: secondaries.map((a) {
                  final c = ArchetypeUtils.color(a.kind);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        c.withValues(alpha: 0.1),
                      border:       Border.all(color: c.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Icon(ArchetypeUtils.icon(a.kind),
                              color: c, size: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(a.headline,
                            style: TextStyle(color: c, fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            _StatStrip(result: result),
          ],
        ),
      ),
    );
  }

}

// ── Stat strip ─────────────────────────────────────────────────────────────

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
          color: AppColors.statAttack,
        ),
        _Stat(
          icon:  Icons.delete_sweep_rounded,
          label: 'Trashers',
          value: result.kingdomCards
              .where((c) =>
                  c.hasTag(CardTag.trashCards) ||
                  c.hasTag(CardTag.trashForBenefit))
              .length,
          color: AppColors.statTrasher,
        ),
        _Stat(
          icon:  Icons.hourglass_empty_rounded,
          label: 'Duration',
          value: result.kingdomCards.where((c) => c.isDuration).length,
          color: AppColors.statDuration,
        ),
        _Stat(
          icon:  Icons.emoji_events_rounded,
          label: 'Alt-VP',
          value: result.victoryCount,
          color: AppColors.statAltVP,
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
    return Semantics(
      label: '$value $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon,
                color: active ? color : Theme.of(context).colorScheme.outlineVariant, size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              color:      active ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize:   16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
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
          Semantics(
            header: true,
            child: Text(
              'SETUP NOTES',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:        Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              border:       Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: notes.asMap().entries.map((entry) {
                final isLast = entry.key == notes.length - 1;
                return Column(
                  children: [
                    Semantics(
                      label: entry.value,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Icon(Icons.info_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary, size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color:    Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  height:   1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 14, endIndent: 14),
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
