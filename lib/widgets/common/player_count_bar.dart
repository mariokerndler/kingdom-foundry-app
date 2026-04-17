import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';

class PlayerCountBar extends ConsumerWidget {
  const PlayerCountBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(configProvider).playerCount;
    final notifier = ref.read(configProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Text(
            'Players',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(5, (i) {
                  final n = i + 2;
                  final selected = n == count;
                  return Padding(
                    padding: EdgeInsets.only(right: i == 4 ? 0 : AppSpacing.sm),
                    child: Semantics(
                      label: '$n players',
                      selected: selected,
                      button: true,
                      child: SizedBox(
                        width: 52,
                        child: FilledButton.tonal(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            notifier.setPlayerCount(n);
                          },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 44),
                            backgroundColor:
                                selected ? cs.primary : cs.surfaceContainer,
                            foregroundColor:
                                selected ? cs.onPrimary : cs.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            '$n',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: selected ? cs.onPrimary : cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
