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
    context:           context,
    isScrollControlled: true,
    backgroundColor:   Colors.transparent,
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
      minChildSize:     0.4,
      maxChildSize:     0.92,
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: AppColors.goldDark, width: 2),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Kingdom History',
                    style: TextStyle(
                      color:      AppColors.parchment,
                      fontSize:   17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(historyProvider.notifier).clear();
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                            color: AppColors.errorRed, fontSize: 13),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.parchmentDim, size: 20),
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
                  controller:  ctrl,
                  padding:     const EdgeInsets.fromLTRB(0, 4, 0, 40),
                  itemCount:   history.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) => _HistoryTile(
                    result: history[i],
                    index:  i,
                    onTap:  () {
                      ref.read(setupResultProvider.notifier).state =
                          history[i];
                      Navigator.pop(context);
                      // Navigate to results screen after sheet closes
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Navigator.of(context).push(buildResultsRoute());
                      });
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
  final SetupResult  result;
  final int          index;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.result,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final expansions = result.kingdomCards.map((c) => c.expansion).toSet();
    final age        = _formatAge(result.generatedAt);
    final primary    = result.primaryArchetype;

    return Semantics(
      label:  'Kingdom ${index + 1}, generated $age. '
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
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardSurface,
                  border: Border.all(color: AppColors.divider),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color:    AppColors.parchmentDim,
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
                      style: const TextStyle(
                        color:    AppColors.parchment,
                        fontSize: 13,
                        height:   1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Expansion badges
                        Wrap(
                          spacing:    4,
                          runSpacing: 4,
                          children: expansions
                              .take(4)
                              .map((e) => ExpansionBadge(
                                    expansion: e,
                                    fontSize:  9,
                                  ))
                              .toList(),
                        ),
                        const Spacer(),
                        // Age + primary archetype
                        Text(
                          primary != null
                              ? '${primary.headline} · $age'
                              : age,
                          style: const TextStyle(
                            color:    AppColors.parchmentDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.divider, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.history_rounded, size: 48, color: AppColors.divider),
        SizedBox(height: 16),
        Text(
          'No kingdoms generated yet.',
          style: TextStyle(color: AppColors.parchmentDim),
        ),
        SizedBox(height: 4),
        Text(
          'Generate your first kingdom to see it here.',
          style: TextStyle(color: AppColors.parchmentDim, fontSize: 12),
        ),
      ],
    ),
  );
}
