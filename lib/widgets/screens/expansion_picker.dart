import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/collection_profile.dart';
import '../../models/expansion.dart';
import '../../models/kingdom_card.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';
import '../common/ui_primitives.dart';

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
      loading: () => const AppStateCard(
        icon: Icons.library_books_outlined,
        title: 'Loading expansions',
        message: 'Building your expansion library...',
      ),
      error: (e, _) => AppStateCard(
        icon: Icons.error_outline_rounded,
        title: 'Could not load expansions',
        message: 'The expansion catalogue failed to load.',
        action: TextButton(
          onPressed: () {
            ref.read(cardDataServiceProvider).invalidate();
            ref.invalidate(allCardsProvider);
            ref.invalidate(availableExpansionsProvider);
          },
          child: const Text('Retry'),
        ),
      ),
      data: (available) {
        final selectable = config.collection == null
            ? available
            : available.intersection(config.collection!.available);
        // Sort alphabetically, then filter by search query.
        final sorted = selectable.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        final filtered = _query.isEmpty
            ? sorted
            : sorted
                .where((e) => e.displayName.toLowerCase().contains(_query))
                .toList();

        final owned = config.ownedExpansions;
        final allOwned = owned.containsAll(selectable);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                Expanded(
                    child: DropdownButton<String>(
                  isExpanded: true,
                  value: config.activeCollection,
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Quick setup')),
                    for (final name in config.collections.keys)
                      DropdownMenuItem(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) {
                    if (value != null) notifier.selectCollection(value);
                  },
                )),
                IconButton(
                    tooltip: 'New collection',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _editCollection(available)),
                if (config.collection != null)
                  IconButton(
                      tooltip: 'Edit collection',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          _editCollection(available, editing: true)),
              ]),
            ),
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  labelText: 'Search expansions',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear expansion search',
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
                  Expanded(
                    child: Text(
                        '${owned.intersection(selectable).length} of ${selectable.length} expansions in this setup',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  TextButton(
                    onPressed: selectable.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            allOwned
                                ? notifier.clearExpansions()
                                : notifier.selectAllExpansions(selectable);
                          },
                    child: Text(
                      allOwned ? 'Clear all' : 'Select all',
                      style: TextStyle(
                        color: allOwned
                            ? Theme.of(context).colorScheme.error
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
              child: selectable.isEmpty && config.collection != null
                  ? const Center(
                      child:
                          Text('Edit the collection to add boxes or promos.'))
                  : filtered.isEmpty
                      ? _EmptySearch(query: _searchCtrl.text)
                      : statsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: AppLoadingStrip(
                              label: 'Updating expansion counts...',
                            ),
                          ),
                          error: (_, __) => const Padding(
                            padding: EdgeInsets.all(16),
                            child: AppStateCard(
                              icon: Icons.error_outline_rounded,
                              title: 'Counts unavailable',
                              message: 'Expansion counts could not be loaded.',
                            ),
                          ),
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

  Future<void> _editCollection(Set<Expansion> available,
      {bool editing = false}) async {
    final config = ref.read(configProvider);
    final List<KingdomCard> catalogue;
    try {
      catalogue = await ref.read(allCardsProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load the card catalogue.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final current = config.collection;
    final promos = <String, List<KingdomCard>>{};
    for (final card in catalogue.where(
        (card) => card.expansion == Expansion.promos && !card.isAuxiliary)) {
      (promos[card.pileId] ??= []).add(card);
    }
    final boxes = available
        .where((expansion) => expansion != Expansion.promos)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final original = current ??
        CollectionProfile(
          boxes: {
            for (final expansion in config.ownedExpansions
                .where((expansion) => expansion != Expansion.promos))
              expansion: CollectionEdition.full,
          },
          promoPiles: config.isExpansionOwned(Expansion.promos)
              ? promos.keys.toSet()
              : {},
          selected: config.ownedExpansions,
        );
    final previousName = editing ? config.activeCollection : null;
    var name = previousName ?? '';
    final owned = {...original.boxes};
    final promoPiles = {...original.promoPiles};
    final selected =
        await showDialog<({String name, CollectionProfile profile})>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, refresh) {
        final trimmed = name.trim();
        final taken = trimmed.toLowerCase() == 'quick setup' ||
            config.collections.keys.any((key) =>
                key != previousName &&
                key.toLowerCase() == trimmed.toLowerCase());
        return AlertDialog(
          scrollable: true,
          title: Text(editing ? 'Edit collection' : 'New collection'),
          content: SizedBox(
            width: 430,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                      initialValue: name,
                      maxLength: 40,
                      decoration: InputDecoration(
                          labelText: 'Collection name',
                          errorText:
                              taken ? 'This name is already in use.' : null),
                      onChanged: (value) => refresh(() => name = value)),
                  const Text(
                      'Choose the boxes and promos you own. Only cards in the catalogue are available.'),
                  for (final expansion in boxes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(expansion.displayName),
                      subtitle: DropdownButton<CollectionEdition>(
                        isExpanded: true,
                        value: owned[expansion],
                        hint: const Text('Not owned'),
                        items: [
                          const DropdownMenuItem<CollectionEdition>(
                              child: Text('Not owned')),
                          for (final edition
                              in updatePackCards.containsKey(expansion)
                                  ? CollectionEdition.values
                                  : [CollectionEdition.full])
                            DropdownMenuItem(
                                value: edition,
                                child: Text(
                                    edition == CollectionEdition.firstEdition &&
                                            catalogue.any((card) =>
                                                card.expansion == expansion &&
                                                card.firstEditionOnly)
                                        ? 'First edition'
                                        : edition.label,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (edition) => refresh(() {
                          if (edition == null) {
                            owned.remove(expansion);
                          } else {
                            owned[expansion] = edition;
                          }
                        }),
                      ),
                    ),
                  if (promos.isNotEmpty) ...[
                    Text('Individual promos',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final entry in promos.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: promoPiles.contains(entry.key),
                        title: Text(
                            entry.value.map((card) => card.name).join(' / ')),
                        onChanged: (value) => refresh(() {
                          if (value == true) {
                            promoPiles.add(entry.key);
                          } else {
                            promoPiles.remove(entry.key);
                          }
                        }),
                      ),
                  ],
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: trimmed.isEmpty || taken
                    ? null
                    : () {
                        final profile = CollectionProfile(
                            boxes: owned, promoPiles: promoPiles, selected: {});
                        Navigator.pop(context, (
                          name: trimmed,
                          profile: profile.withSelection({
                            ...original.selected,
                            ...profile.available.difference(original.available),
                          })
                        ));
                      },
                child: const Text('Save collection')),
          ],
        );
      }),
    );
    if (!mounted || selected == null) return;
    ref.read(configProvider.notifier).saveCollection(
        selected.name, selected.profile,
        previousName: previousName);
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        const _GroupHeader(title: 'Large Expansions'),
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
        const _GroupHeader(title: 'Small Expansions'),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
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
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: '${expansion.displayName}, '
          '${stats.kingdom} kingdom piles'
          '${stats.landscape > 0 ? ", ${stats.landscape} landscape cards" : ""}. '
          '${selected ? "Selected" : "Not selected"}. Tap to toggle.',
      button: true,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 180),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.07)
              : cs.surfaceContainer,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
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
                        Text(
                          '${stats.kingdom} piles${stats.landscape > 0 ? ' · ${stats.landscape} landscape' : ''}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedContainer(
                    duration: AppMotion.duration(context, 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected ? cs.primary : Colors.transparent,
                      border: Border.all(
                        color: selected ? cs.primary : cs.outline,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                            size: 16, color: cs.onPrimary)
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
