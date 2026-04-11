import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/setup_result.dart';
import '../../providers/generation_provider.dart';
import '../../providers/history_provider.dart';
import '../../screens/results_screen.dart';
import '../../utils/app_theme.dart';
import '../common/expansion_badge.dart';

/// Shows a bottom sheet with the last 10 kingdoms.
/// Tapping an entry restores it to [setupResultProvider] so the user can
/// push to the ResultsScreen without regenerating.
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
    final history = ref.watch(historyProvider);

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
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Kingdom History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(historyProvider.notifier).clear();
                      },
                      child: Text(
                        'Clear',
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

            if (history.isEmpty)
              const Expanded(child: _EmptyHistory())
            else
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 40),
                  itemCount: history.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _HistoryTile(
                    result: history[i],
                    index: i,
                    onTap: () {
                      ref.read(setupResultProvider.notifier).state = history[i];
                      // Capture navigator before pop to avoid stale context.
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(buildResultsRoute());
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SetupResult result;
  final int index;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.result,
    required this.index,
    required this.onTap,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index bubble
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
                child: Text(
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
                    // Card names
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
                        // Expansion badges
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
                        // Age + primary archetype
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

              const SizedBox(width: 8),
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 48, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No kingdoms generated yet.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Generate your first kingdom to see it here.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
            ),
          ],
        ),
      );
}
