import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';

/// Compact 2–6 player toggle shown below the AppBar on the config screen.
class PlayerCountBar extends ConsumerWidget {
  const PlayerCountBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count    = ref.watch(configProvider).playerCount;
    final notifier = ref.read(configProvider.notifier);

    return Semantics(
      label: 'Player count: $count players',
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          children: [
            const Text(
              'Players',
              style: TextStyle(
                color:    AppColors.parchmentDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 12),
            ...List.generate(5, (i) {
              final n        = i + 2;
              final selected = n == count;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Semantics(
                  label:   '$n players',
                  selected: selected,
                  button:  true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.setPlayerCount(n);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.gold
                            : AppColors.cardSurface,
                        border: Border.all(
                          color: selected ? AppColors.gold : AppColors.divider,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color:      selected ? Colors.black : AppColors.parchmentDim,
                          fontSize:   13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
