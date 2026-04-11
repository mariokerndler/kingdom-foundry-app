import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expansion.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';

class ExpansionPickerTab extends ConsumerStatefulWidget {
  const ExpansionPickerTab({super.key});

  @override
  ConsumerState<ExpansionPickerTab> createState() => _ExpansionPickerTabState();
}

class _ExpansionPickerTabState extends ConsumerState<ExpansionPickerTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final availableAsync = ref.watch(availableExpansionsProvider);
    final statsAsync = ref.watch(expansionStatsProvider);
    final config = ref.watch(configProvider);
    final notifier = ref.read(configProvider.notifier);

    return availableAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading expansions: $e')),
      data: (available) {
        // Sort alphabetically, then filter by search query.
        final sorted = available.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final filtered = _query.isEmpty
            ? sorted
            : sorted
                .where((e) => e.displayName.toLowerCase().contains(_query))
                .toList();

        final owned = config.ownedExpansions;
        final allOwned = owned.length == available.length;

        // Total kingdom cards from owned expansions.
        final totalKingdom = statsAsync.whenOrNull(
          data: (s) =>
              owned.fold<int>(0, (sum, e) => sum + (s[e]?.kingdom ?? 0)),
        );

        return Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search expansions…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),

            // ── Stats + bulk actions bar ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  _KingdomCountChip(
                    count: totalKingdom,
                    owned: owned.length,
                    total: available.length,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      allOwned
                          ? notifier.clearExpansions()
                          : notifier.selectAllExpansions(available);
                    },
                    child: Text(
                      allOwned ? 'Clear all' : 'Select all',
                      style: TextStyle(
                        color: allOwned
                            ? AppColors.errorRed // keep — destructive action
                            : Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Expansion list ──────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptySearch(query: _searchCtrl.text)
                  : statsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (stats) => _GroupedList(
                        expansions: filtered,
                        stats: stats,
                        owned: owned,
                        onToggle: notifier.toggleExpansion,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Grouped list (Large ≥ 20 kingdom cards / Small < 20) ──────────────────

class _GroupedList extends StatelessWidget {
  final List<Expansion> expansions;
  final Map<Expansion, ExpansionStats> stats;
  final Set<Expansion> owned;
  final ValueChanged<Expansion> onToggle;

  const _GroupedList({
    required this.expansions,
    required this.stats,
    required this.owned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final large =
        expansions.where((e) => (stats[e]?.kingdom ?? 0) >= 20).toList();
    final small =
        expansions.where((e) => (stats[e]?.kingdom ?? 0) < 20).toList();

    // Only show group headers when both groups are non-empty.
    final showGroups = large.isNotEmpty && small.isNotEmpty;

    if (!showGroups) {
      return _FlatList(
          expansions: expansions,
          stats: stats,
          owned: owned,
          onToggle: onToggle);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        _GroupHeader(title: 'Large Expansions', count: large.length),
        ...large.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ExpansionTile(
                expansion: e,
                stats: stats[e] ?? (kingdom: 0, landscape: 0),
                selected: owned.contains(e),
                onTap: () => onToggle(e),
              ),
            )),
        const SizedBox(height: 10),
        _GroupHeader(title: 'Small Expansions', count: small.length),
        ...small.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ExpansionTile(
                expansion: e,
                stats: stats[e] ?? (kingdom: 0, landscape: 0),
                selected: owned.contains(e),
                onTap: () => onToggle(e),
              ),
            )),
      ],
    );
  }
}

class _FlatList extends StatelessWidget {
  final List<Expansion> expansions;
  final Map<Expansion, ExpansionStats> stats;
  final Set<Expansion> owned;
  final ValueChanged<Expansion> onToggle;

  const _FlatList({
    required this.expansions,
    required this.stats,
    required this.owned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: expansions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final e = expansions[i];
        return _ExpansionTile(
          expansion: e,
          stats: stats[e] ?? (kingdom: 0, landscape: 0),
          selected: owned.contains(e),
          onTap: () => onToggle(e),
        );
      },
    );
  }
}

// ── Group header label ─────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;

  const _GroupHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single expansion tile ──────────────────────────────────────────────────

class _ExpansionTile extends StatelessWidget {
  final Expansion expansion;
  final ExpansionStats stats;
  final bool selected;
  final VoidCallback onTap;

  const _ExpansionTile({
    required this.expansion,
    required this.stats,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(expansion.badgeColorValue);
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: '${expansion.displayName}, '
          '${stats.kingdom} kingdom cards'
          '${stats.landscape > 0 ? ", ${stats.landscape} landscape cards" : ""}. '
          '${selected ? "Selected" : "Not selected"}. Tap to toggle.',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? badgeColor.withValues(alpha: 0.10)
              : cs.surfaceContainer,
          border: Border.all(
            color: selected ? badgeColor : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? badgeColor
                          : cs.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expansion.displayName,
                          style: TextStyle(
                            color:
                                selected ? cs.onSurface : cs.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _CountPill(
                              icon: Icons.grid_view_rounded,
                              label: '${stats.kingdom} kingdom',
                              color: selected
                                  ? cs.onSurfaceVariant
                                  : cs.onSurfaceVariant.withValues(alpha: 0.55),
                            ),
                            if (stats.landscape > 0) ...[
                              const SizedBox(width: 8),
                              _CountPill(
                                icon: Icons.map_outlined,
                                label: '${stats.landscape} landscape',
                                color: selected
                                    ? cs.primary.withValues(alpha: 0.85)
                                    : cs.primary.withValues(alpha: 0.45),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? badgeColor : Colors.transparent,
                      border: Border.all(
                        color: selected ? badgeColor : cs.outlineVariant,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tiny icon + label pill ─────────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CountPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      );
}

// ── Top status chip ────────────────────────────────────────────────────────

class _KingdomCountChip extends StatelessWidget {
  final int? count; // null while loading
  final int owned;
  final int total;

  const _KingdomCountChip({
    required this.count,
    required this.owned,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (count == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    }

    final enough = count! >= 10;
    final color = enough ? AppColors.successGreen : AppColors.errorRed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enough
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '$count kingdom · $owned/$total sets',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty search state ─────────────────────────────────────────────────────

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'No expansions match "$query"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      );
}
