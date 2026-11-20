import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/setup_exception.dart';
import '../models/card_tag.dart';
import '../models/expansion.dart';
import '../models/kingdom_card.dart';
import '../models/setup_result.dart';
import '../models/share_payload.dart';
import '../models/table_checklist.dart';
import '../models/table_setup_choice.dart';
import '../providers/card_data_providers.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/history_provider.dart';
import '../providers/translation_provider.dart';
import '../utils/app_theme.dart';
import '../utils/archetype_utils.dart';
import '../utils/print_setup.dart';
import '../widgets/cards/archetype_card.dart';
import '../widgets/cards/kingdom_card_widget.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/ui_primitives.dart';
import '../widgets/screens/card_ban_list.dart';

/// Groups a flat kingdom card list into display slots.
/// Cards sharing a splitPileId collapse into a single pile slot.
/// The lower-cost card is the primary (shown on the tile).
List<_KingdomSlot> _splitPileSlots(List<KingdomCard> cards) {
  final seen = <String>{};
  final slots = <_KingdomSlot>[];
  final byPile = <String, List<KingdomCard>>{};

  for (final c in cards) {
    if (c.splitPileId != null) {
      (byPile[c.splitPileId!] ??= []).add(c);
    }
  }

  for (final c in cards) {
    if (c.splitPileId == null) {
      slots.add(_KingdomSlot(c, const []));
    } else if (!seen.contains(c.splitPileId)) {
      seen.add(c.splitPileId!);
      final pile = byPile[c.splitPileId!]!
        ..sort((a, b) {
          final cmp = a.cost.compareTo(b.cost);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
      slots.add(_KingdomSlot(pile.first, pile.skip(1).toList()));
    }
  }
  return slots;
}

class _KingdomSlot {
  final KingdomCard primary;
  final List<KingdomCard> splitPileCards;

  const _KingdomSlot(this.primary, this.splitPileCards);

  String get label => [
        primary.name,
        ...splitPileCards.map((c) => c.name),
      ].join(' / ');
}

/// Public route builder — shared by ConfigurationScreen and HistorySheet.
Route<void> buildResultsRoute() => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const ResultsScreen(),
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, _, child) =>
          MediaQuery.disableAnimationsOf(context)
              ? child
              : FadeTransition(
                  opacity:
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                            .animate(CurvedAnimation(
                                parent: animation, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
    );

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(setupResultProvider);
    final status = ref.watch(generationStatusProvider);
    final isRegenerating = status == GenerationStatus.loading;

    if (result == null) {
      return const Scaffold(
        appBar: _EmptyResultsAppBar(),
        body: AppStateCard(
          icon: Icons.casino_rounded,
          title: 'No kingdom generated yet',
          message:
              'Generate or import a kingdom from the configuration screen to review it here.',
        ),
      );
    }

    final library = ref.watch(historyProvider);
    return Scaffold(
      appBar: _ResultsAppBar(
        result: result,
        isRegenerating: isRegenerating,
        isFavorite: library.isFavorite(result),
        canToggleFavorite: !library.isLoading && !library.couldNotLoad,
        onCopy: () => _copy(context, _kingdomList(result), 'Kingdom list'),
        onCopyShare: () =>
            _copy(context, encodeSharePayload(result), 'Share code'),
        onCopyLink: () => _copy(
            context,
            SharePayload.shareLink(Uri.base, encodeSharePayload(result))
                .toString(),
            'Share link'),
        onCopyFullSetup: () =>
            _copy(context, encodeFullSetup(result), 'Setup with settings'),
        onPrintSetup: () => _print(context, ref, result),
        onUseSetupSettings: () {
          ref.read(configProvider.notifier).useSetupSettings(
                rules: result.rulesSnapshot!,
                playerCount: result.playerCount!,
                presetId: result.presetId,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Applied the board’s rules and player count.')),
          );
        },
        onToggleFavorite: () => _toggleFavorite(context, ref, result),
      ),
      body: _ResultsBody(result: result, isRegenerating: isRegenerating),
    );
  }

  void _print(BuildContext context, WidgetRef ref, SetupResult result) {
    final players = result.playerCount ?? ref.read(configProvider).playerCount;
    final slots = _splitPileSlots(result.kingdomCards);
    final printed = printSetup({
      'title': result.savedName.isEmpty ? 'Kingdom Foundry' : result.savedName,
      'subtitle': '$players players · ${slots.length} kingdom piles',
      'sections': [
        [
          'Kingdom piles',
          [
            for (final slot in slots)
              '${slot.label} (${slot.primary.costString}) · ${slot.primary.expansion.displayName}'
          ],
          true
        ],
        [
          'Landscapes',
          [
            for (final card in result.landscapeCards)
              '${card.name} · ${card.typeString} · ${card.expansion.displayName}'
          ],
          false
        ],
        ['Table setup', tableChecklist(result, players), false],
        if (result.savedNotes.isNotEmpty)
          [
            'Notes',
            [result.savedNotes],
            false
          ],
      ],
    });
    if (!printed) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the print preview.')));
    }
  }

  String _kingdomList(SetupResult result) {
    final slots = _splitPileSlots(result.kingdomCards);
    final kingdom = slots.asMap().entries.map((e) {
      final slot = e.value;
      return '${e.key + 1}. ${slot.label} (${slot.primary.costString})';
    }).join('\n');
    if (!result.hasLandscape) return kingdom;
    final landscapes = result.landscapeCards
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value.name}');
    return '$kingdom\n\nLandscapes:\n${landscapes.join('\n')}';
  }

  Future<void> _copy(BuildContext context, String text, String label) async {
    var message = '$label copied to clipboard';
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      message = 'Could not copy to clipboard';
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    SetupResult result,
  ) async {
    final saved =
        await ref.read(historyProvider.notifier).toggleFavorite(result);
    if (!context.mounted || !saved) return;
    final isFavorite = ref.read(historyProvider).isFavorite(result);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFavorite
              ? 'Saved kingdom preset locally'
              : 'Removed kingdom preset from saved',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _EmptyResultsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _EmptyResultsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Kingdom Board'));
  }
}

enum _ResultsMenuAction {
  printSetup,
  copyKingdom,
  copyShareCode,
  copyShareLink,
  copyFullSetup,
  useSetupSettings
}

// ── App bar ────────────────────────────────────────────────────────────────

class _ResultsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final SetupResult result;
  final bool isRegenerating;
  final bool isFavorite;
  final bool canToggleFavorite;
  final VoidCallback onCopy;
  final VoidCallback onCopyShare;
  final VoidCallback onCopyLink;
  final VoidCallback onCopyFullSetup;
  final VoidCallback onPrintSetup;
  final VoidCallback onUseSetupSettings;
  final VoidCallback onToggleFavorite;

  const _ResultsAppBar({
    required this.result,
    required this.isRegenerating,
    required this.isFavorite,
    required this.canToggleFavorite,
    required this.onCopy,
    required this.onCopyShare,
    required this.onCopyLink,
    required this.onCopyFullSetup,
    required this.onPrintSetup,
    required this.onUseSetupSettings,
    required this.onToggleFavorite,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final expansionCount =
        result.kingdomCards.map((c) => c.expansion).toSet().length;
    final tt = Theme.of(context).textTheme;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(result.savedName.isEmpty ? 'Kingdom Board' : result.savedName,
              style: tt.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            '${result.kingdomSlotIds.length} piles · $expansionCount expansion${expansionCount == 1 ? '' : 's'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: isFavorite ? 'Remove saved preset' : 'Save kingdom preset',
          onPressed:
              isRegenerating || !canToggleFavorite ? null : onToggleFavorite,
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFavorite
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        PopupMenuButton<_ResultsMenuAction>(
          tooltip: 'Kingdom actions',
          popUpAnimationStyle: AppMotion.menu(context),
          enabled: !isRegenerating,
          onSelected: (action) {
            switch (action) {
              case _ResultsMenuAction.printSetup:
                onPrintSetup();
              case _ResultsMenuAction.copyKingdom:
                onCopy();
              case _ResultsMenuAction.copyShareCode:
                onCopyShare();
              case _ResultsMenuAction.copyShareLink:
                onCopyLink();
              case _ResultsMenuAction.copyFullSetup:
                onCopyFullSetup();
              case _ResultsMenuAction.useSetupSettings:
                onUseSetupSettings();
            }
          },
          itemBuilder: (context) => [
            if (kIsWeb)
              const PopupMenuItem(
                value: _ResultsMenuAction.printSetup,
                child: ListTile(
                    leading: Icon(Icons.print_outlined),
                    title: Text('Print table setup'),
                    contentPadding: EdgeInsets.zero),
              ),
            const PopupMenuItem(
              value: _ResultsMenuAction.copyKingdom,
              child: ListTile(
                leading: Icon(Icons.copy_rounded),
                title: Text('Copy kingdom list'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: _ResultsMenuAction.copyShareCode,
              child: ListTile(
                leading: Icon(Icons.qr_code_rounded),
                title: Text('Copy share code'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (kIsWeb)
              const PopupMenuItem(
                value: _ResultsMenuAction.copyShareLink,
                child: ListTile(
                  leading: Icon(Icons.link_rounded),
                  title: Text('Copy share link'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if ((result.rulesSnapshot != null && result.playerCount != null) ||
                result.hasTableSetupChoices)
              const PopupMenuItem(
                value: _ResultsMenuAction.copyFullSetup,
                child: ListTile(
                  leading: Icon(Icons.copy_all_rounded),
                  title: Text('Copy full setup'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            if (result.rulesSnapshot != null && result.playerCount != null)
              const PopupMenuItem(
                value: _ResultsMenuAction.useSetupSettings,
                child: ListTile(
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Use this setup’s settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
          icon: Icon(
            Icons.more_horiz_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Regenerating overlay ───────────────────────────────────────────────────

// ── Main scrollable body ───────────────────────────────────────────────────

final _compactBoardProvider = StateProvider<bool>((ref) => false);
final _sortByExpansionProvider = StateProvider<bool>((ref) => false);

class _ResultsBody extends ConsumerWidget {
  final SetupResult result;
  final bool isRegenerating;

  const _ResultsBody({required this.result, required this.isRegenerating});

  Future<void> _showTableSetup(BuildContext context, WidgetRef ref) async {
    var platinumColony = result.platinumColonyChoice;
    var shelters = result.sheltersChoice;
    final players = result.playerCount ?? ref.read(configProvider).playerCount;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        final preview = result.copyWith(
            platinumColonyChoice: platinumColony, sheltersChoice: shelters);
        return AlertDialog(
          title: const Text('Table setup checklist'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TableSetupChoice>(
                    initialValue: platinumColony,
                    decoration: const InputDecoration(
                        labelText: 'Platinum and Colony (Prosperity)'),
                    items: [
                      for (final choice in TableSetupChoice.values)
                        DropdownMenuItem(
                            value: choice, child: Text(choice.label)),
                    ],
                    onChanged: (choice) =>
                        setState(() => platinumColony = choice!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TableSetupChoice>(
                    initialValue: shelters,
                    decoration: const InputDecoration(
                        labelText: 'Shelters (Dark Ages)'),
                    items: [
                      for (final choice in TableSetupChoice.values)
                        DropdownMenuItem(
                            value: choice, child: Text(choice.label)),
                    ],
                    onChanged: (choice) => setState(() => shelters = choice!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                      'Choices apply to this board and its saved library entry. '
                      'Use a full setup code to share these choices.'),
                  const SizedBox(height: 16),
                  for (final note in tableChecklist(preview, players))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(note)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Apply')),
          ],
        );
      }),
    );
    if (apply != true || !context.mounted) return;
    final current = ref.read(setupResultProvider);
    if (current == null || current.generatedAt != result.generatedAt) return;
    final updated = current.copyWith(
        platinumColonyChoice: platinumColony, sheltersChoice: shelters);
    ref.read(setupResultProvider.notifier).state = updated;
    await ref.read(historyProvider.notifier).updateTableChoices(updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final playerCount = result.playerCount ?? config.playerCount;
    final checklist = tableChecklist(result, playerCount);
    final extraIds = result.setupChoices.values.toSet();
    final extraCards = extraIds.isEmpty
        ? const <KingdomCard>[]
        : (ref.watch(allCardsProvider).valueOrNull ?? const <KingdomCard>[])
            .where((card) => extraIds.contains(card.id));
    final showStrategyTips = config.rules.showStrategyTips;
    final missingExpansions = {
      for (final card in [
        ...result.kingdomCards,
        ...result.landscapeCards,
        ...extraCards
      ])
        if (!config.usesCard(card))
          if (card.firstEditionOnly)
            '${card.name} (first edition)'
          else
            card.expansion.displayName,
    }.toList()
      ..sort();
    final slots = _splitPileSlots(result.kingdomCards);
    final compact = ref.watch(_compactBoardProvider);
    final sortByExpansion = ref.watch(_sortByExpansionProvider);
    if (sortByExpansion) {
      slots.sort((a, b) {
        final expansion = a.primary.expansion.displayName
            .compareTo(b.primary.expansion.displayName);
        if (expansion != 0) return expansion;
        final cost = a.primary.cost.compareTo(b.primary.cost);
        return cost != 0 ? cost : a.primary.name.compareTo(b.primary.name);
      });
    }
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useWideLayout = viewportWidth >= 1200 && textScale <= 1.15;
    final useSingleColumn = viewportWidth < 720 || textScale > 1.15;
    final boardPadding =
        useWideLayout ? max(24.0, (viewportWidth - 1360) / 2) : 12.0;
    final crossAxisCount =
        compact ? 1 : (useWideLayout ? 5 : (useSingleColumn ? 1 : 2));
    final cardHeight = (compact ? 96.0 : (useSingleColumn ? 222.0 : 232.0)) *
        max(1.0, textScale);
    const spacing = 12.0;

    return CustomScrollView(
      slivers: [
        if (result.savedNotes.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(boardPadding, 12, boardPadding, 0),
              child: SelectableText(result.savedNotes),
            ),
          ),
        if (missingExpansions.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(boardPadding, 12, boardPadding, 0),
              child: Text(
                  'Outside your selected collection: ${missingExpansions.join(', ')}.'),
            ),
          ),
        SliverToBoxAdapter(
          child: _ResultWidthBox(
            enabled: useWideLayout,
            child:
                _RerollControls(result: result, isRegenerating: isRegenerating),
          ),
        ),

        SliverToBoxAdapter(
            child: Padding(
          padding: EdgeInsets.fromLTRB(boardPadding, 0, boardPadding, 12),
          child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                    label: const Text('Compact board'),
                    selected: compact,
                    onSelected: (value) =>
                        ref.read(_compactBoardProvider.notifier).state = value),
                FilterChip(
                    label: const Text('Sort by expansion'),
                    selected: sortByExpansion,
                    onSelected: (value) => ref
                        .read(_sortByExpansionProvider.notifier)
                        .state = value),
                TextButton.icon(
                    icon: const Icon(Icons.checklist_rounded),
                    label: const Text('Table setup'),
                    onPressed: isRegenerating
                        ? null
                        : () => _showTableSetup(context, ref)),
              ]),
        )),
        // ── 10-card grid (staggered entrance) ────────────────────────────
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: boardPadding),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _StaggeredEntry(
                key: ValueKey((i, slots[i].primary.id)),
                index: i,
                child: KingdomCardWidget(
                  compact: compact,
                  card: slots[i].primary,
                  splitPileCards: slots[i].splitPileCards,
                  index: i + 1,
                  locked: result.isSlotLocked(
                    slots[i].primary.splitPileId ?? slots[i].primary.id,
                  ),
                  canToggleLock: !isRegenerating,
                  onToggleLock: () => toggleKingdomSlotLock(
                    ref,
                    slots[i].primary.splitPileId ?? slots[i].primary.id,
                  ),
                ),
              ),
              childCount: slots.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: cardHeight,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
          ),
        ),

        if (result.selectionRationale.isNotEmpty)
          SliverToBoxAdapter(
            child: _ResultWidthBox(
              enabled: useWideLayout,
              child:
                  _SelectionRationaleSection(lines: result.selectionRationale),
            ),
          ),

        // ── Landscape cards (Events / Landmarks / Projects / Ways / Allies)
        if (result.landscapeCards.isNotEmpty)
          SliverToBoxAdapter(
            child: _ResultWidthBox(
              enabled: useWideLayout,
              child: _LandscapeSection(result: result),
            ),
          ),

        // ── Setup notes ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ResultWidthBox(
            enabled: useWideLayout,
            child: _SetupNotesSection(notes: checklist),
          ),
        ),

        // ── Random first player ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ResultWidthBox(
            enabled: useWideLayout,
            child: _RandomFirstPlayer(playerCount: playerCount),
          ),
        ),

        // ── Strategy guide ────────────────────────────────────────────────
        if (showStrategyTips && result.archetypes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _ResultWidthBox(
              enabled: useWideLayout,
              child: const SectionHeader(
                title: 'Strategy Guide',
                subtitle: 'Heuristic archetypes detected for this kingdom.',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _ResultWidthBox(
              enabled: useWideLayout,
              child: _ArchetypeBanner(result: result),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: useWideLayout ? boardPadding : 0,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => ArchetypeCard(
                  archetype: result.archetypes[i],
                  isPrimary: i == 0,
                ),
                childCount: result.archetypes.length,
              ),
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
  final int index;
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
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _delayTimer = Timer(Duration(milliseconds: min(widget.index, 5) * 30), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? widget.child
      : FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _slide, child: widget.child),
        );
}

class _ResultWidthBox extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _ResultWidthBox({
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: child,
      ),
    );
  }
}

// ── Landscape section ──────────────────────────────────────────────────────

class _LandscapeSection extends StatelessWidget {
  final SetupResult result;
  const _LandscapeSection({required this.result});

  @override
  Widget build(BuildContext context) {
    // Group by type label for display
    final groups = <String, List<KingdomCard>>{};
    for (final c in result.landscapeCards) {
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

  static String _landscapeLabel(KingdomCard c) {
    if (c.isEvent) return 'Events';
    if (c.isLandmark) return 'Landmarks';
    if (c.isProject) return 'Projects';
    if (c.isWay) return 'Ways';
    if (c.isAlly) return 'Allies';
    if (c.isProphecy) return 'Prophecies';
    if (c.isTrait) return 'Traits';
    return 'Landscape';
  }
}

class _LandscapeGroup extends ConsumerWidget {
  final String label;
  final List<KingdomCard> cards;
  const _LandscapeGroup({required this.label, required this.cards});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ...cards.map((c) {
          final localized = ref.watch(localizedCardProvider(c));
          final current = ref.watch(setupResultProvider);
          final isLocked = current?.isLandscapeLocked(c.id) ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.landscapeAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(localized.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              )),
                      const SizedBox(height: 3),
                      Text(localized.text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? AppColors.landscapeAccent
                                      .withValues(alpha: 0.10)
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              border: Border.all(
                                color: isLocked
                                    ? AppColors.landscapeAccent
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                              ),
                            ),
                            child: Text(
                              isLocked
                                  ? 'Locked for rerolls'
                                  : 'Unlocked for rerolls',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: isLocked
                                        ? AppColors.landscapeAccent
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: ref.watch(generationStatusProvider) ==
                                    GenerationStatus.loading
                                ? null
                                : () => toggleLandscapeLock(ref, c.id),
                            icon: Icon(
                              isLocked
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                            ),
                            label: Text(
                              '${isLocked ? 'Unlock' : 'Lock'} ${localized.name}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

enum _RerollAction { kingdom, landscapes, clearLocks, replace }

class _RerollControls extends ConsumerStatefulWidget {
  final SetupResult result;
  final bool isRegenerating;

  const _RerollControls({required this.result, required this.isRegenerating});

  @override
  ConsumerState<_RerollControls> createState() => _RerollControlsState();
}

class _RerollControlsState extends ConsumerState<_RerollControls> {
  bool _rerolled = false;

  Future<void> _reroll(
      {_RerollAction? action,
      String? replaceSlotId,
      String? incomingSlotId}) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final success = await rerollCurrentResult(
      container,
      rerollKingdom: action != _RerollAction.landscapes,
      rerollLandscapes: action != _RerollAction.kingdom,
      replaceSlotId: replaceSlotId,
      incomingSlotId: incomingSlotId,
    );
    if (!mounted) return;
    if (success) {
      setState(() => _rerolled = true);
      return;
    }
    setState(() => _rerolled = false);
    final message =
        ref.read(generationErrorProvider) ?? 'Could not reroll this kingdom.';
    clearGenerationFeedback(ref);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _replacePile() async {
    final result = widget.result;
    final slots = _splitPileSlots(result.kingdomCards);
    final id = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
              title: const Text('Replace a pile'),
              children: [
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'Choose an unlocked pile. The other nine piles stay.')),
                for (final slot in slots)
                  SimpleDialogOption(
                    onPressed: widget.result.isSlotLocked(
                            slot.primary.splitPileId ?? slot.primary.id)
                        ? null
                        : () => Navigator.pop(context,
                            slot.primary.splitPileId ?? slot.primary.id),
                    child: Text(
                        '${slot.label}${widget.result.isSlotLocked(slot.primary.splitPileId ?? slot.primary.id) ? ' (locked)' : ''}'),
                  ),
              ],
            ));
    if (id == null || !mounted) return;
    final outgoing = slots.firstWhere(
        (slot) => (slot.primary.splitPileId ?? slot.primary.id) == id);
    final container = ProviderScope.containerOf(context, listen: false);
    final options = previewPileReplacements(container, id);
    final incoming = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Replace ${outgoing.label}'),
        contentPadding: const EdgeInsets.only(top: 12),
        content: SizedBox(
          width: 580,
          height: min(460, MediaQuery.sizeOf(context).height * 0.56),
          child: FutureBuilder(
            future: options,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error is SetupException
                      ? error.message
                      : 'Could not load replacement piles.'),
                ));
              }
              final candidates = snapshot.data;
              if (candidates == null) {
                return const Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Checking replacements'));
              }
              if (candidates.isEmpty) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No legal replacement keeps the other nine piles under your rules and landscape locks.'),
                ));
              }
              final currentIds =
                  result.landscapeCards.map((card) => card.id).toSet();
              final changes = <String, String>{};
              for (final entry in candidates.entries) {
                final nextIds =
                    entry.value.landscapes.map((card) => card.id).toSet();
                final added = entry.value.landscapes
                    .where((card) => !currentIds.contains(card.id));
                final removed = result.landscapeCards
                    .where((card) => !nextIds.contains(card.id));
                final setupAffected =
                    !mapEquals(result.setupChoices, entry.value.setupChoices);
                final messages = [
                  for (final card in added)
                    'Adds ${card.isAlly ? 'an Ally' : 'a Prophecy'}',
                  for (final card in removed) 'Removes ${card.name}',
                  if (setupAffected) 'Updates table setup choices',
                ];
                if (messages.isNotEmpty) {
                  changes[entry.key] = messages.join(' · ');
                }
              }
              return Column(children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      'Choose a legal alternative. Setup notes update for the new board.'),
                ),
                Expanded(
                    child: CardBanListTab.replacements(
                  replacementCards:
                      candidates.values.expand((value) => value.cards).toList(),
                  replacementNotes: changes,
                  onSelectPile: (slotId) => Navigator.pop(context, slotId),
                )),
              ]);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      ),
    );
    if (incoming != null &&
        mounted &&
        identical(ref.read(setupResultProvider), result)) {
      await _reroll(replaceSlotId: id, incomingSlotId: incoming);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final isRegenerating = widget.isRegenerating;
    final lockedCount =
        result.lockedSlotIds.length + result.lockedLandscapeIds.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      liveRegion: isRegenerating,
                      child: FilledButton.icon(
                        onPressed: isRegenerating ? null : () => _reroll(),
                        icon: isRegenerating &&
                                !MediaQuery.disableAnimationsOf(context)
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(isRegenerating
                                ? Icons.hourglass_top_rounded
                                : Icons.casino_rounded),
                        label: Text(isRegenerating
                            ? 'Rerolling kingdom…'
                            : 'Reroll unlocked cards'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (ref.watch(canUndoRerollProvider))
                IconButton(
                  tooltip: 'Undo reroll',
                  onPressed: isRegenerating
                      ? null
                      : () {
                          undoLastReroll(ProviderScope.containerOf(context,
                              listen: false));
                          setState(() => _rerolled = false);
                        },
                  icon: const Icon(Icons.undo_rounded),
                ),
              PopupMenuButton<_RerollAction>(
                enabled: !isRegenerating,
                tooltip: 'More reroll options',
                requestFocus: true,
                popUpAnimationStyle: AppMotion.menu(context),
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (action) {
                  if (action == _RerollAction.clearLocks) {
                    clearAllLocks(ref);
                  } else if (action == _RerollAction.replace) {
                    _replacePile();
                  } else {
                    _reroll(action: action);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: _RerollAction.replace,
                      child: Text('Replace a pile…')),
                  const PopupMenuItem(
                      value: _RerollAction.kingdom,
                      child: Text('Reroll only kingdom cards')),
                  const PopupMenuItem(
                      value: _RerollAction.landscapes,
                      child: Text('Reroll only landscapes')),
                  PopupMenuItem(
                      value: _RerollAction.clearLocks,
                      enabled: lockedCount > 0,
                      child: const Text('Clear all locks')),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: _rerolled,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(result.generatedAt),
              tween: Tween(begin: _rerolled ? 1 : 0, end: 0),
              duration: AppMotion.duration(context, 420),
              curve: Curves.easeOut,
              builder: (context, pulse, child) => DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primary.withValues(alpha: pulse * 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: child,
              ),
              child: Text(
                _rerolled
                    ? (lockedCount > 0
                        ? 'Kingdom updated · $lockedCount locked'
                        : 'Kingdom updated.')
                    : (lockedCount > 0
                        ? '$lockedCount locked · Kept on reroll'
                        : 'Lock cards you want to keep.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionRationaleSection extends StatelessWidget {
  final List<String> lines;

  const _SelectionRationaleSection({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why This Kingdom',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  int? _picked;
  bool _rolling = false;

  Future<void> _roll() async {
    final playerCount = widget.playerCount;
    HapticFeedback.selectionClick();
    if (!MediaQuery.disableAnimationsOf(context)) {
      setState(() => _rolling = true);
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
    }
    setState(() {
      _picked = Random().nextInt(playerCount) + 1;
      _rolling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                    'Pick the first player',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, 200),
                      reverseDuration: AppMotion.duration(context, 160),
                      switchInCurve: Curves.easeOut,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previous
                              .map((child) => ExcludeSemantics(child: child)),
                          if (current != null) current
                        ],
                      ),
                      child: Text(
                        _picked == null
                            ? 'Choose from ${widget.playerCount} players.'
                            : 'Player $_picked goes first.',
                        key: ValueKey(_picked),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: _rolling ? null : _roll,
              tooltip: 'Pick random first player',
              icon: _rolling
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.casino_rounded),
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
    final primary = result.archetypes.first;
    final secondaries = result.archetypes.skip(1).toList();

    return Semantics(
      label: 'Primary strategy: ${primary.headline}. '
          '${secondaries.isNotEmpty ? 'Also: ${secondaries.map((a) => a.headline).join(', ')}.' : ''}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
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
                spacing: 6,
                runSpacing: 6,
                children: secondaries.map((a) {
                  final c = ArchetypeUtils.color(a.kind);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: c.withValues(alpha: 0.55)),
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
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12)),
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
    return Wrap(
      alignment: WrapAlignment.spaceAround,
      spacing: 18,
      runSpacing: 12,
      children: [
        _Stat(
          icon: Icons.local_fire_department_rounded,
          label: 'Attacks',
          value: result.kingdomCards.where((c) => c.isAttack).length,
          color: AppColors.statAttack,
        ),
        _Stat(
          icon: Icons.delete_sweep_rounded,
          label: 'Trashers',
          value: result.kingdomCards
              .where((c) =>
                  c.hasTag(CardTag.trashCards) ||
                  c.hasTag(CardTag.trashForBenefit))
              .length,
          color: AppColors.statTrasher,
        ),
        _Stat(
          icon: Icons.hourglass_empty_rounded,
          label: 'Duration',
          value: result.kingdomCards.where((c) => c.isDuration).length,
          color: AppColors.statDuration,
        ),
        _Stat(
          icon: Icons.emoji_events_rounded,
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
  final String label;
  final int value;
  final Color color;
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
                color: active
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                size: 18),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
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
              'TABLE SETUP',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.4)),
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
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 15),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.45,
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
