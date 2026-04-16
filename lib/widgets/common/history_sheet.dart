import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/setup_result.dart';
import '../../providers/generation_provider.dart';
import '../../providers/history_provider.dart';
import '../../screens/results_screen.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';

/// Shows a bottom sheet with recent kingdoms and locally saved presets.
void showHistorySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HistorySheet(),
  );
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final history = state.history;
    final favorites = state.favorites;
    final hasEntries = favorites.isNotEmpty || history.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.collections_bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kingdom Library',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(historyProvider.notifier).clearHistory();
                      },
                      child: Text(
                        'Clear history',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.errorRed,
                            ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (!hasEntries)
              const Expanded(child: _EmptyHistory())
            else
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
                  children: [
                    _SectionLabel(
                      icon: Icons.star_rounded,
                      title: 'Saved presets',
                      subtitle: favorites.isEmpty
                          ? 'Star any kingdom to keep it locally until you delete it.'
                          : '${favorites.length} saved kingdom preset${favorites.length == 1 ? '' : 's'}',
                    ),
                    if (favorites.isEmpty)
                      const _SectionEmptyState(
                        icon: Icons.star_border_rounded,
                        message: 'No saved presets yet.',
                      )
                    else
                      ...favorites.asMap().entries.map(
                            (entry) => _HistoryTile(
                              result: entry.value,
                              index: entry.key,
                              isFavorite: true,
                              leadingIcon: Icons.star_rounded,
                              onTap: () =>
                                  _openResult(context, ref, entry.value),
                              onToggleFavorite: () => ref
                                  .read(historyProvider.notifier)
                                  .removeFavorite(entry.value),
                            ),
                          ),
                    const Divider(height: 24, indent: 16, endIndent: 16),
                    _SectionLabel(
                      icon: Icons.history_rounded,
                      title: 'Recent history',
                      subtitle: history.isEmpty
                          ? 'Generate a kingdom to add it here.'
                          : 'Newest first, up to 10 recent kingdoms.',
                    ),
                    if (history.isEmpty)
                      const _SectionEmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        message: 'No recent kingdoms yet.',
                      )
                    else
                      ...history.asMap().entries.map(
                            (entry) => _HistoryTile(
                              result: entry.value,
                              index: entry.key,
                              isFavorite: state.isFavorite(entry.value),
                              onTap: () =>
                                  _openResult(context, ref, entry.value),
                              onToggleFavorite: () => ref
                                  .read(historyProvider.notifier)
                                  .toggleFavorite(entry.value),
                            ),
                          ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openResult(BuildContext context, WidgetRef ref, SetupResult result) {
    ref.read(setupResultProvider.notifier).state = result;
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(buildResultsRoute());
  }
}

class _HistoryTile extends StatelessWidget {
  final SetupResult result;
  final int index;
  final bool isFavorite;
  final IconData? leadingIcon;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _HistoryTile({
    required this.result,
    required this.index,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final expansions = result.kingdomCards.map((c) => c.expansion).toSet();
    final age = _formatAge(result.generatedAt);
    final primary = result.primaryArchetype;

    return Semantics(
      label: 'Kingdom ${index + 1}, generated $age. '
          '${result.kingdomCards.map((c) => c.name).join(', ')}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: leadingIcon != null
                    ? Icon(
                        leadingIcon,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.kingdomCards.map((c) => c.name).join(', '),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: expansions
                              .take(4)
                              .map((e) => ExpansionBadge(
                                    expansion: e,
                                    fontSize: 11,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            primary != null
                                ? '${primary.headline} · $age'
                                : age,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Delete saved preset' : 'Save preset',
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.outlineVariant,
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SectionEmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_rounded,
                size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No saved presets or history yet.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate a kingdom, then star it to keep it locally.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
            ),
          ],
        ),
      );
}
