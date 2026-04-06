import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../screens/results_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/screens/card_ban_list.dart';
import '../widgets/screens/expansion_picker.dart';
import '../widgets/screens/rules_section.dart';

class ConfigurationScreen extends ConsumerWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final status = ref.watch(generationStatusProvider);
    final isLoading = status == GenerationStatus.loading;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const _AppTitle(),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.library_books_outlined), text: 'Expansions'),
              Tab(icon: Icon(Icons.tune_rounded),           text: 'Rules'),
              Tab(icon: Icon(Icons.block_rounded),          text: 'Ban Cards'),
            ],
          ),
        ),

        body: const TabBarView(
          children: [
            ExpansionPickerTab(),
            RulesTab(),
            CardBanListTab(),
          ],
        ),

        // Active rules badge on the FAB label
        floatingActionButton: _GenerateFab(
          isLoading:      isLoading,
          ownedCount:     config.ownedExpansions.length,
          activeRuleCount: config.rules.activeRuleDescriptions.length,
          onGenerate: () => _generate(context, ref),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    // Quick guard — show snackbar if no expansions selected
    final config = ref.read(configProvider);
    if (config.ownedExpansions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Select at least one expansion first.'),
          backgroundColor: AppColors.errorRed,
          behavior:        SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final success = await generateKingdom(ref);

    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const ResultsScreen(),
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end:   Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
        ),
      );
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      _showErrorDialog(context, error);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.errorRed),
            SizedBox(width: 8),
            Text('Cannot Generate Kingdom',
                style: TextStyle(color: AppColors.parchment, fontSize: 16)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: AppColors.parchmentDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

// ── App title with subtitle ────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        const Text('Dominion Setup',
            style: TextStyle(
              color:      AppColors.parchment,
              fontSize:   18,
              fontWeight: FontWeight.w700,
            )),
        Text('Kingdom Generator',
            style: TextStyle(
              color:    AppColors.gold.withValues(alpha: 0.8),
              fontSize: 11,
            )),
      ],
    );
  }
}

// ── Generate FAB ───────────────────────────────────────────────────────────

class _GenerateFab extends StatelessWidget {
  final bool     isLoading;
  final int      ownedCount;
  final int      activeRuleCount;
  final VoidCallback onGenerate;

  const _GenerateFab({
    required this.isLoading,
    required this.ownedCount,
    required this.activeRuleCount,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed:    isLoading ? null : onGenerate,
      backgroundColor: isLoading ? AppColors.goldDark : AppColors.gold,
      label: isLoading
          ? const Row(
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:  AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
                SizedBox(width: 10),
                Text('Generating...',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.casino_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Generate Kingdom',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                if (activeRuleCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeRuleCount rule${activeRuleCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
