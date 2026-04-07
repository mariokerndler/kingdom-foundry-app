import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dominion_card.dart';
import '../../models/expansion.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';
import '../common/section_header.dart';

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
    final config          = ref.watch(configProvider);
    final disabledCount   = config.disabledCardIds.length;

    return cardsByExpAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => _ErrorState(
        message: 'Could not load card list.',
        onRetry: () => ref.invalidate(cardsByExpansionProvider),
      ),
      data: (cardsByExp) {
        // Filter to only owned expansions
        final owned = Map.fromEntries(
          cardsByExp.entries
              .where((e) => config.isExpansionOwned(e.key)),
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
              controller:    _searchCtrl,
              disabledCount: disabledCount,
              onClearAll:    () => ref
                  .read(configProvider.notifier)
                  .enableAllCards(),
            ),

            SectionHeader(
              title:    'Kingdom Cards',
              subtitle: '$totalOwned cards from ${owned.length} expansion${owned.length == 1 ? '' : 's'}',
            ),

            // Grouped list
            Expanded(
              child: filtered.isEmpty
                  ? _NoResults(query: _query)
                  : ListView.builder(
                      padding:     const EdgeInsets.only(bottom: 100),
                      itemCount:   _flatItemCount(filtered),
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
  Map<Expansion, List<DominionCard>> _applyQuery(
    Map<Expansion, List<DominionCard>> source,
    String query,
  ) {
    if (query.isEmpty) return source;
    final result = <Expansion, List<DominionCard>>{};
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
  int _flatItemCount(Map<Expansion, List<DominionCard>> grouped) {
    return grouped.entries.fold(0, (s, e) => s + 1 + e.value.length);
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    Map<Expansion, List<DominionCard>> grouped,
    ConfigState config,
    WidgetRef ref,
  ) {
    // Walk through headers + card rows sequentially
    int cursor = 0;
    for (final entry in grouped.entries) {
      if (index == cursor) {
        return _ExpansionHeader(expansion: entry.key, count: entry.value.length);
      }
      cursor++;
      final cardIndex = index - cursor;
      if (cardIndex < entry.value.length) {
        final card = entry.value[cardIndex];
        return _CardRow(
          card:       card,
          isDisabled: config.isCardDisabled(card.id),
          onToggle:   () =>
              ref.read(configProvider.notifier).toggleCard(card.id),
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
  final int                   disabledCount;
  final VoidCallback          onClearAll;

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
              style:       const TextStyle(color: AppColors.parchment),
              decoration: const InputDecoration(
                hintText:    'Search cards...',
                prefixIcon:  Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (disabledCount > 0) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onClearAll,
              icon:  const Icon(Icons.restore, size: 16),
              label: Text('Enable all ($disabledCount)',
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
  final int       count;

  const _ExpansionHeader({required this.expansion, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          ExpansionBadge(expansion: expansion, fontSize: 11),
          const SizedBox(width: 10),
          Text(
            expansion.displayName,
            style: const TextStyle(
              color:      AppColors.parchment,
              fontSize:   13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$count cards',
            style: const TextStyle(
              color:   AppColors.parchmentDim,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card row ────────────────────────────────────────────────────────────────

class _CardRow extends StatelessWidget {
  final DominionCard card;
  final bool         isDisabled;
  final VoidCallback onToggle;

  const _CardRow({
    required this.card,
    required this.isDisabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:  '${card.name}, ${isDisabled ? "banned" : "available"}',
      hint:   'Double tap to ${isDisabled ? "enable" : "ban"}',
      button: true,
      excludeSemantics: true,
      child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity:  isDisabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        isDisabled
                ? AppColors.background
                : AppColors.cardSurface,
            border:       Border.all(
              color: isDisabled ? AppColors.divider : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Cost coin
              _CostBadge(cost: card.cost),
              const SizedBox(width: 10),

              // Name + type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: TextStyle(
                        color:      isDisabled
                            ? AppColors.parchmentDim
                            : AppColors.parchment,
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        decoration: isDisabled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      card.typeString,
                      style: const TextStyle(
                        color:   AppColors.parchmentDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Checkbox
              Checkbox(
                value:     !isDisabled,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
      ),  // Semantics
    );
  }
}

// ── Cost badge ──────────────────────────────────────────────────────────────

class _CostBadge extends StatelessWidget {
  final int cost;
  const _CostBadge({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.goldDark,
      ),
      alignment: Alignment.center,
      child: Text(
        '$cost',
        style: const TextStyle(
          color:      Colors.black,
          fontSize:   13,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_books_outlined,
              size: 48, color: AppColors.parchmentDim),
          SizedBox(height: 16),
          Text('No expansions selected.',
              style: TextStyle(color: AppColors.parchmentDim)),
          SizedBox(height: 4),
          Text('Go to the Expansions tab to pick your sets.',
              style: TextStyle(color: AppColors.parchmentDim, fontSize: 12)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 40, color: AppColors.parchmentDim),
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
  final String       message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.errorRed),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        ],
      ),
    );
  }
}
