import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';

/// Compact 2–6 player toggle shown below the AppBar on the config screen.
class PlayerCountBar extends ConsumerWidget {
  const PlayerCountBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(configProvider).playerCount;
    final notifier = ref.read(configProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Player count: $count players',
      child: Container(
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            Text('Players', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 12),
            ...List.generate(5, (i) {
              final n = i + 2;
              final selected = n == count;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: '$n players',
                  child: Semantics(
                    label: '$n players',
                    selected: selected,
                    button: true,
                    excludeSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setPlayerCount(n);
                        },
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? cs.primary : cs.surfaceContainer,
                            border: Border.all(
                              color: selected ? cs.primary : cs.outlineVariant,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color:
                                  selected ? cs.onPrimary : cs.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
