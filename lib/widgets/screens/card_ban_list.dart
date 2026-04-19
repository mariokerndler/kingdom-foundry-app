import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/kingdom_card.dart';
import '../../models/expansion.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';
import '../common/section_header.dart';
import '../common/ui_primitives.dart';

class CardBanListTab extends ConsumerStatefulWidget {
  const CardBanListTab({super.key});

  @override
  ConsumerState<CardBanListTab> createState() => _CardBanListTabState();
}

class _CardBanListTabState extends ConsumerState<CardBanListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cardsByExpAsync = ref.watch(cardsByExpansionProvider);
    final config = ref.watch(configProvider);
    final disabledCount = config.disabledCardIds.length;

    return cardsByExpAsync.when(
      loading: () => const AppStateCard(
        icon: Icons.block_rounded,
        title: 'Loading card ban list',
        message: 'Preparing cards from your selected expansions...',
      ),
      error: (e, _) => _ErrorState(
        message: 'Could not load card list.',
        onRetry: () => ref.invalidate(cardsByExpansionProvider),
      ),
      data: (cardsByExp) {
        // Filter to only owned expansions
        final owned = Map.fromEntries(
          cardsByExp.entries.where((e) => config.isExpansionOwned(e.key)),
        );

        if (owned.isEmpty) {
          return const _EmptyState();
        }

        // Apply search query
        final filtered = _applyQuery(owned, _query);
        final totalOwned = owned.values.fold(0, (s, l) => s + l.length);

        return Column(
          children: [
            // Search bar + clear-all
            _SearchBar(
              controller: _searchCtrl,
              disabledCount: disabledCount,
              onClearAll: () =>
                  ref.read(configProvider.notifier).enableAllCards(),
            ),

            SectionHeader(
              title: 'Banned Cards',
              subtitle:
                  '$disabledCount banned from $totalOwned cards across ${owned.length} expansion${owned.length == 1 ? '' : 's'}',
            ),

            // Grouped list
            Expanded(
              child: filtered.isEmpty
                  ? _NoResults(query: _query)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _flatItemCount(filtered),
                      itemBuilder: (ctx, i) =>
                          _buildItem(ctx, i, filtered, config, ref),
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── List building helpers ────────────────────────────────────────────────

  /// Returns an ordered list of (expansion, cards) pairs, query-filtered.
  Map<Expansion, List<KingdomCard>> _applyQuery(
    Map<Expansion, List<KingdomCard>> source,
    String query,
  ) {
    if (query.isEmpty) return source;
    final result = <Expansion, List<KingdomCard>>{};
    for (final entry in source.entries) {
      final matches = entry.value
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              c.typeString.toLowerCase().contains(query))
          .toList();
      if (matches.isNotEmpty) result[entry.key] = matches;
    }
    return result;
  }

  /// Each expansion has 1 header + N card rows.
  int _flatItemCount(Map<Expansion, List<KingdomCard>> grouped) {
    return grouped.entries.fold(0, (s, e) => s + 1 + e.value.length);
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    Map<Expansion, List<KingdomCard>> grouped,
    ConfigState config,
    WidgetRef ref,
  ) {
    // Walk through headers + card rows sequentially
    int cursor = 0;
    for (final entry in grouped.entries) {
      if (index == cursor) {
        return _ExpansionHeader(
            expansion: entry.key, count: entry.value.length);
      }
      cursor++;
      final cardIndex = index - cursor;
      if (cardIndex < entry.value.length) {
        final card = entry.value[cardIndex];
        return _CardRow(
          card: card,
          isDisabled: config.isCardDisabled(card.id),
          onToggle: () => ref.read(configProvider.notifier).toggleCard(card.id),
        );
      }
      cursor += entry.value.length;
    }
    return const SizedBox.shrink();
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int disabledCount;
  final VoidCallback onClearAll;

  const _SearchBar({
    required this.controller,
    required this.disabledCount,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search cards',
                helperText: 'Filter by card name or type.',
                hintText: 'Search cards...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (disabledCount > 0) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.restore, size: 16),
              label: Text('Unban all ($disabledCount)',
                  style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Expansion group header ──────────────────────────────────────────────────

class _ExpansionHeader extends StatelessWidget {
  final Expansion expansion;
  final int count;

  const _ExpansionHeader({required this.expansion, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          ExpansionBadge(expansion: expansion, fontSize: 11),
          const SizedBox(width: 10),
          Text(
            expansion.displayName,
            style: TextStyle(
                color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '$count cards',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Card row ────────────────────────────────────────────────────────────────

class _CardRow extends StatelessWidget {
  final KingdomCard card;
  final bool isDisabled;
  final VoidCallback onToggle;

  const _CardRow({
    required this.card,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDisabled
            ? AppColors.errorRed.withValues(alpha: 0.08)
            : cs.surfaceContainer,
        border: Border.all(
          color: isDisabled ? AppColors.errorRed : cs.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CostBadge(cost: card.cost),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.typeString,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics(
                        label:
                            '${isDisabled ? "Ban enabled" : "Ban disabled"} for ${card.name}',
                        toggled: isDisabled,
                        child: Switch.adaptive(
                          value: isDisabled,
                          onChanged: (_) => onToggle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        isDisabled
                            ? Icons.block_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color:
                            isDisabled ? AppColors.errorRed : AppColors.successGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDisabled ? 'Banned from generation' : 'Allowed in generation',
                        style: TextStyle(
                          color: isDisabled
                              ? AppColors.errorRed
                              : AppColors.successGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cost badge ──────────────────────────────────────────────────────────────

class _CostBadge extends StatelessWidget {
  final int cost;
  const _CostBadge({required this.cost});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary,
      ),
      alignment: Alignment.center,
      child: Text(
        '$cost',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Empty states ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_books_outlined,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No expansions selected.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Go to the Expansions tab to choose cards you can ban.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ignore: prefer_const_constructors
          Icon(Icons.search_off_rounded, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No cards match "$query"',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends ConsumerWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return AppStateCard(
      icon: Icons.error_outline_rounded,
      title: 'Ban list unavailable',
      message: message,
      accentColor: cs.error,
      action: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry'),
        style: TextButton.styleFrom(foregroundColor: cs.primary),
      ),
    );
  }
}
