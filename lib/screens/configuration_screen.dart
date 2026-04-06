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

// ── Shared page-transition route ───────────────────────────────────────────

/// Fade + slight slide-up into [ResultsScreen].
Route<void> _resultsRoute() => PageRouteBuilder<void>(
      pageBuilder:               (_, __, ___) => const ResultsScreen(),
      transitionDuration:        const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );

// ── Screen ─────────────────────────────────────────────────────────────────

class ConfigurationScreen extends ConsumerWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config   = ref.watch(configProvider);
    final status   = ref.watch(generationStatusProvider);
    final isLoading = status == GenerationStatus.loading;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const _AppTitle(),
          actions: [
            IconButton(
              icon:    const Icon(Icons.paste_rounded),
              tooltip: 'Import kingdom from clipboard',
              onPressed: () => _showImportDialog(context, ref),
            ),
            const SizedBox(width: 4),
          ],
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

        floatingActionButton: _GenerateFab(
          isLoading:       isLoading,
          ownedCount:      config.ownedExpansions.length,
          activeRuleCount: config.rules.activeRuleDescriptions.length,
          onGenerate:      () => _generate(context, ref),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  // ── Generate ──────────────────────────────────────────────────────────────

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
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
      Navigator.of(context).push(_resultsRoute());
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      _showErrorDialog(context, error);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );

    if (text == null || !context.mounted) return;

    HapticFeedback.mediumImpact();
    final success = await importKingdom(ref, text);

    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).push(_resultsRoute());
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      _showErrorDialog(context, error);
    }
  }

  // ── Error dialog ──────────────────────────────────────────────────────────

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

// ── App title ──────────────────────────────────────────────────────────────

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
  final bool         isLoading;
  final int          ownedCount;
  final int          activeRuleCount;
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
      onPressed:       isLoading ? null : onGenerate,
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
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w700)),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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

// ── Import dialog ──────────────────────────────────────────────────────────

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _ctrl   = TextEditingController();
  List<String> _parsed = [];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    // Pre-fill if the clipboard already contains a kingdom list.
    Clipboard.getData('text/plain').then((data) {
      if (!mounted || data?.text == null) return;
      final names = parseKingdomText(data!.text!);
      if (names.length == 10) {
        _ctrl.text = data.text!;
      }
    });
  }

  void _onChanged() {
    setState(() => _parsed = parseKingdomText(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _parsed.length == 10;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      titlePadding:    const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding:  const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: const Row(
        children: [
          Icon(Icons.paste_rounded, color: AppColors.gold, size: 20),
          SizedBox(width: 8),
          Text('Import Kingdom',
              style: TextStyle(
                color:      AppColors.parchment,
                fontSize:   17,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a kingdom list shared from another player\'s device.',
              style: TextStyle(color: AppColors.parchmentDim, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Text area
            TextField(
              controller: _ctrl,
              maxLines:   12,
              minLines:   5,
              autofocus:  true,
              style: const TextStyle(
                  color: AppColors.parchment, fontSize: 12, height: 1.6),
              decoration: const InputDecoration(
                hintText: '1. Village (\$3)\n2. Smithy (\$4)\n…',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 10),

            // Live validation feedback
            if (_ctrl.text.trim().isNotEmpty)
              _ParsePreview(parsed: _parsed, isValid: isValid),

            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.parchmentDim)),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.pop(context, _ctrl.text) : null,
          child: Text(
            'Import Kingdom',
            style: TextStyle(
              color:      isValid ? AppColors.gold : AppColors.divider,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Import live-preview ────────────────────────────────────────────────────

class _ParsePreview extends StatelessWidget {
  final List<String> parsed;
  final bool         isValid;

  const _ParsePreview({required this.parsed, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? AppColors.successGreen : AppColors.errorRed;
    final count = parsed.length;

    return AnimatedContainer(
      duration:    const Duration(milliseconds: 200),
      padding:     const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration:  BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        border:       Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: color,
                size:  15,
              ),
              const SizedBox(width: 8),
              Text(
                isValid
                    ? '$count cards found — ready to import'
                    : '$count of 10 cards found',
                style: TextStyle(
                  color:      color,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (parsed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              parsed.join(' · '),
              style: TextStyle(
                color:    color.withValues(alpha: 0.75),
                fontSize: 11,
                height:   1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
