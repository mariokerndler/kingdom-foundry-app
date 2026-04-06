import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expansion.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../providers/generation_provider.dart';
import '../../utils/app_theme.dart';
import '../common/section_header.dart';

class ExpansionPickerTab extends ConsumerStatefulWidget {
  const ExpansionPickerTab({super.key});

  @override
  ConsumerState<ExpansionPickerTab> createState() => _ExpansionPickerTabState();
}

class _ExpansionPickerTabState extends ConsumerState<ExpansionPickerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final availableAsync = ref.watch(availableExpansionsProvider);
    final config         = ref.watch(configProvider);
    final countAsync     = ref.watch(availableCardCountProvider);

    return availableAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error loading expansions: $e')),
      data: (available) {
        final owned    = config.ownedExpansions;
        final allOwned = owned.length == available.length;

        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            SectionHeader(
              title:    'Your Collection',
              subtitle: 'Select every set you own.',
              trailing: TextButton(
                onPressed: () => allOwned
                    ? ref.read(configProvider.notifier).clearExpansions()
                    : ref.read(configProvider.notifier).selectAllExpansions(available),
                child: Text(
                  allOwned ? 'Clear all' : 'Select all',
                  style: const TextStyle(color: AppColors.gold, fontSize: 13),
                ),
              ),
            ),

            // Card count indicator
            countAsync.when(
              loading: () => const SizedBox.shrink(),
              error:   (_, __) => const SizedBox.shrink(),
              data: (count) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _CountBar(count: count),
              ),
            ),

            const SizedBox(height: 4),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing:    8,
                runSpacing: 8,
                children: available
                    .toList()
                    .map((exp) => _ExpansionChip(
                          expansion: exp,
                          selected:  owned.contains(exp),
                          onTap: () => ref
                              .read(configProvider.notifier)
                              .toggleExpansion(exp),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Card-count bar ─────────────────────────────────────────────────────────

class _CountBar extends StatelessWidget {
  final int count;
  const _CountBar({required this.count});

  @override
  Widget build(BuildContext context) {
    final enough = count >= 10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        enough
            ? AppColors.successGreen.withValues(alpha: 0.12)
            : AppColors.errorRed.withValues(alpha: 0.12),
        border:       Border.all(
          color: enough ? AppColors.successGreen : AppColors.errorRed,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            enough ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size:  16,
            color: enough ? AppColors.successGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 8),
          Text(
            enough
                ? '$count kingdom cards available'
                : '$count kingdom cards — need at least 10',
            style: TextStyle(
              color:      enough ? AppColors.successGreen : AppColors.errorRed,
              fontSize:   13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual chip ────────────────────────────────────────────────────────

class _ExpansionChip extends StatelessWidget {
  final Expansion    expansion;
  final bool         selected;
  final VoidCallback onTap;

  const _ExpansionChip({
    required this.expansion,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = Color(expansion.badgeColorValue);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        selected
              ? badgeColor.withValues(alpha: 0.22)
              : AppColors.cardSurface,
          border:       Border.all(
            color: selected ? badgeColor : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width:  8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? badgeColor : AppColors.parchmentDim,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              expansion.displayName,
              style: TextStyle(
                color:      selected ? AppColors.parchment : AppColors.parchmentDim,
                fontSize:   13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
