import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/setup_exception.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../screens/results_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/common/history_sheet.dart';
import '../widgets/common/player_count_bar.dart';
import '../widgets/screens/card_ban_list.dart';
import '../widgets/screens/expansion_picker.dart';
import '../widgets/screens/rules_section.dart';

// ── Shared page-transition route defined in results_screen.dart ────────────

// ── Screen ─────────────────────────────────────────────────────────────────

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
          actions: [
            IconButton(
              icon: Icon(
                config.useDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: config.useDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              onPressed: () => ref
                  .read(configProvider.notifier)
                  .setUseDarkMode(!config.useDarkMode),
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Kingdom history',
              onPressed: () => showHistorySheet(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.paste_rounded),
              tooltip: 'Import kingdom from clipboard',
              onPressed: () => _showImportDialog(context, ref),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.library_books_outlined), text: 'Expansions'),
              Tab(icon: Icon(Icons.tune_rounded), text: 'Rules'),
              Tab(icon: Icon(Icons.block_rounded), text: 'Ban Cards'),
            ],
          ),
        ),
        body: const Column(
          children: [
            PlayerCountBar(),
            Expanded(
              child: TabBarView(
                children: [
                  ExpansionPickerTab(),
                  RulesTab(),
                  CardBanListTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _GenerateFab(
          isLoading: isLoading,
          ownedCount: config.ownedExpansions.length,
          activeRuleCount: config.rules.activeRuleDescriptions.length,
          onGenerate: () => _generate(context, ref),
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
          content: Text('Select at least one expansion first.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (config.rules.costCurve.enabled && !config.rules.costCurve.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the cost curve so it assigns exactly 10 kingdom slots.',
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final success = await generateKingdom(ref);

    if (!context.mounted) return;

    if (success) {
      Navigator.of(context).push(buildResultsRoute());
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      final reason = ref.read(generationFailureReasonProvider);
      _showErrorDialog(context, error, reason);
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
      Navigator.of(context).push(buildResultsRoute());
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      final reason = ref.read(generationFailureReasonProvider);
      _showErrorDialog(context, error, reason);
    }
  }

  // ── Error dialog ──────────────────────────────────────────────────────────

  void _showErrorDialog(
    BuildContext context,
    String message,
    SetupFailureReason? reason,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _SetupErrorDialog(message: message, reason: reason),
    );
  }
}

// ── App title ──────────────────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Kingdom Foundry',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
        Text('Kingdom Generator',
            style: TextStyle(
              color: cs.primary.withValues(alpha: 0.8),
              fontSize: 11,
            )),
      ],
    );
  }
}

// ── Generate FAB ───────────────────────────────────────────────────────────

class _GenerateFab extends StatelessWidget {
  final bool isLoading;
  final int ownedCount;
  final int activeRuleCount;
  final VoidCallback onGenerate;

  const _GenerateFab({
    required this.isLoading,
    required this.ownedCount,
    required this.activeRuleCount,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      onPressed: isLoading ? null : onGenerate,
      backgroundColor:
          isLoading ? cs.primary.withValues(alpha: 0.6) : cs.primary,
      label: isLoading
          ? Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Generating...',
                    style: TextStyle(
                        color: cs.onPrimary, fontWeight: FontWeight.w700)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeRuleCount rule${activeRuleCount == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 11, color: cs.onPrimary),
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
  final _ctrl = TextEditingController();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(
        children: [
          Icon(Icons.paste_rounded,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text('Import Kingdom',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a kingdom list shared from another player\'s device.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Text area
            TextField(
              controller: _ctrl,
              maxLines: 12,
              minLines: 5,
              autofocus: true,
              style: const TextStyle(fontSize: 12, height: 1.6),
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
          child: Text('Cancel',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.pop(context, _ctrl.text) : null,
          child: Text(
            'Import Kingdom',
            style: TextStyle(
              color: isValid
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
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
  final bool isValid;

  const _ParsePreview({required this.parsed, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final color = isValid ? AppColors.successGreen : AppColors.errorRed;
    final count = parsed.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
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
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                isValid
                    ? '$count cards found — ready to import'
                    : '$count of 10 cards found',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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
                color: color.withValues(alpha: 0.75),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Contextual error dialog ────────────────────────────────────────────────

class _SetupErrorDialog extends StatelessWidget {
  final String message;
  final SetupFailureReason? reason;

  const _SetupErrorDialog({required this.message, required this.reason});

  @override
  Widget build(BuildContext context) {
    final (icon, title, suggestion) = _content(reason);

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(
        children: [
          Icon(icon, color: AppColors.errorRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    );
  }

  static (IconData, String, String) _content(SetupFailureReason? reason) {
    switch (reason) {
      case SetupFailureReason.poolTooSmall:
        return (
          Icons.inventory_2_outlined,
          'Not Enough Cards',
          'Enable more expansions or turn off active rules (No Attacks, Max Cost, etc.) to increase the card pool.',
        );
      case SetupFailureReason.requirementImpossible:
        return (
          Icons.rule_folder_outlined,
          'Rule Cannot Be Satisfied',
          'A requirement rule (Village / Trashing / +Buy) has no matching cards after your other filters. Disable a conflicting rule or enable more expansions.',
        );
      case SetupFailureReason.varietyImpossible:
        return (
          Icons.library_books_outlined,
          'Not Enough Expansions',
          'The expansion variety requirement exceeds the number of selected expansions. Enable more sets or lower the variety setting.',
        );
      case null:
        return (
          Icons.warning_amber_rounded,
          'Cannot Generate Kingdom',
          'Check your expansion selection and active rules, then try again.',
        );
    }
  }
}
