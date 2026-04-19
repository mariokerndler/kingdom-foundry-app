import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/setup_exception.dart';
import '../models/share_payload.dart';
import '../providers/card_data_providers.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../screens/results_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/common/history_sheet.dart';
import '../widgets/common/player_count_bar.dart';
import '../widgets/common/ui_primitives.dart';
import '../widgets/screens/card_ban_list.dart';
import '../widgets/screens/expansion_picker.dart';
import '../widgets/screens/rules_section.dart';

// ── Shared page-transition route defined in results_screen.dart ────────────

// ── Screen ─────────────────────────────────────────────────────────────────

class ConfigurationScreen extends ConsumerStatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  ConsumerState<ConfigurationScreen> createState() =>
      _ConfigurationScreenState();
}

enum _ConfigTab { expansions, rules, bans }

class _ConfigurationScreenState extends ConsumerState<ConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _ConfigTab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(configProvider, (_, __) {
      if (ref.read(generationStatusProvider) == GenerationStatus.error) {
        clearGenerationFeedback(ref);
      }
    });
    ref.listen<SetupFailureReason?>(generationFailureReasonProvider, (_, next) {
      if (next != null) _jumpToTab(_tabForReason(next));
    });

    final config = ref.watch(configProvider);
    final status = ref.watch(generationStatusProvider);
    final error = ref.watch(generationErrorProvider);
    final reason = ref.watch(generationFailureReasonProvider);
    final isLoading = status == GenerationStatus.loading;
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useScrollableTabs = width < 420 || textScale > 1.15;

    return Scaffold(
      appBar: AppBar(
        title: const _AppTitle(),
        actions: [
          IconButton(
            tooltip: 'Open kingdom library',
            onPressed: () => showHistorySheet(context, ref),
            icon: const Icon(Icons.collections_bookmark_rounded),
          ),
          IconButton(
            tooltip: 'Import kingdom',
            onPressed: () => _showImportDialog(context, ref),
            icon: const Icon(Icons.paste_rounded),
          ),
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
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: useScrollableTabs,
          tabs: const [
            Tab(icon: Icon(Icons.library_books_outlined), text: 'Expansions'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Rules'),
            Tab(icon: Icon(Icons.block_rounded), text: 'Ban Cards'),
          ],
        ),
      ),
      body: Column(
        children: [
          const PlayerCountBar(),
          if (status == GenerationStatus.error && error != null)
            _ConfigurationErrorBanner(
              message: error,
              reason: reason,
              onReview: () => _jumpToTab(_tabForReason(reason)),
              onDismiss: () => clearGenerationFeedback(ref),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ExpansionPickerTab(),
                RulesTab(),
                CardBanListTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GeneratePanel(
        isLoading: isLoading,
        config: config,
        onGenerate: () => _generate(context, ref),
      ),
    );
  }

  void _jumpToTab(_ConfigTab tab) {
    if (_tabController.index == tab.index) return;
    _tabController.animateTo(tab.index);
  }

  _ConfigTab _tabForReason(SetupFailureReason? reason) {
    switch (reason) {
      case SetupFailureReason.requirementImpossible:
        return _ConfigTab.rules;
      case SetupFailureReason.varietyImpossible:
        return _ConfigTab.expansions;
      case SetupFailureReason.poolTooSmall:
      case null:
        return _ConfigTab.expansions;
    }
  }

  // ── Generate ──────────────────────────────────────────────────────────────

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final config = ref.read(configProvider);
    if (config.ownedExpansions.isEmpty) {
      setGenerationFeedback(
        ref,
        message: 'Select at least one expansion before generating a kingdom.',
        reason: SetupFailureReason.poolTooSmall,
      );
      _jumpToTab(_ConfigTab.expansions);
      return;
    }
    if (config.rules.costCurve.enabled && !config.rules.costCurve.isValid) {
      setGenerationFeedback(
        ref,
        message:
            'Complete the cost curve so it assigns exactly 10 kingdom slots before generating.',
      );
      _jumpToTab(_ConfigTab.rules);
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
      if (reason != null) {
        _jumpToTab(_tabForReason(reason));
        return;
      }
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
              fontSize: 12,
            )),
      ],
    );
  }
}

// ── Generate FAB ───────────────────────────────────────────────────────────

class _ConfigurationErrorBanner extends StatelessWidget {
  final String message;
  final SetupFailureReason? reason;
  final VoidCallback onReview;
  final VoidCallback onDismiss;

  const _ConfigurationErrorBanner({
    required this.message,
    required this.reason,
    required this.onReview,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (title, cta) = switch (reason) {
      SetupFailureReason.requirementImpossible =>
        ('A rule combination needs attention', 'Review rules'),
      SetupFailureReason.varietyImpossible =>
        ('Expansion variety needs attention', 'Review expansions'),
      SetupFailureReason.poolTooSmall => ('Card pool is too small', 'Review setup'),
      null => ('Setup needs attention', 'Review setup'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.errorRed, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: onReview,
                        child: Text(cta),
                      ),
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratePanel extends ConsumerWidget {
  final bool isLoading;
  final ConfigState config;
  final VoidCallback onGenerate;

  const _GeneratePanel({
    required this.isLoading,
    required this.config,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final poolCountAsync = ref.watch(selectedPoolCountProvider);
    final chips = [
      AppSummaryChip(
        icon: Icons.library_books_outlined,
        label: 'sets',
        value: '${config.ownedExpansions.length}',
      ),
      AppSummaryChip(
        icon: Icons.tune_rounded,
        label: 'rules',
        value: '${config.rules.activeRuleDescriptions.length}',
      ),
      AppSummaryChip(
        icon: Icons.block_rounded,
        label: 'banned',
        value: '${config.disabledCardIds.length}',
        color: config.disabledCardIds.isEmpty ? null : AppColors.errorRed,
      ),
      AppSummaryChip(
        icon: Icons.grid_view_rounded,
        label: 'pool',
        value: poolCountAsync.maybeWhen(
          data: (count) => '$count',
          orElse: () => '...',
        ),
        color: poolCountAsync.maybeWhen(
          data: (count) => count >= 10 ? AppColors.successGreen : AppColors.errorRed,
          orElse: () => null,
        ),
      ),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Current setup',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (poolCountAsync.maybeWhen(
                    data: (count) => count < 10,
                    orElse: () => false,
                  ))
                    Text(
                      'Need at least 10 cards',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.errorRed,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in chips) ...[
                      chip,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onGenerate,
                  icon: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                          ),
                        )
                      : const Icon(Icons.casino_rounded),
                  label: Text(
                    isLoading ? 'Generating kingdom...' : 'Generate kingdom',
                  ),
                ),
              ),
            ],
          ),
        ),
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
  bool _isShareCode = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    // Pre-fill if the clipboard already contains a kingdom list.
      Clipboard.getData('text/plain').then((data) {
        if (!mounted || data?.text == null) return;
        final names = parseKingdomText(data!.text!);
        if (names.length == 10 || SharePayload.looksLikeShareCode(data.text!)) {
          _ctrl.text = data.text!;
        }
      });
  }

  void _onChanged() {
    setState(() {
      _parsed = parseKingdomText(_ctrl.text);
      _isShareCode = SharePayload.looksLikeShareCode(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _parsed.length == 10 || _isShareCode;
    final hasInput = _ctrl.text.trim().isNotEmpty;

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
              'Paste either a kingdom list or a compact share code from another player.',
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
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 13, height: 1.6),
              decoration: InputDecoration(
                labelText: 'Kingdom list or share code',
                helperText:
                    'Paste 10 cards or a compact code from another player.',
                hintText: '1. Village (\$3)\n2. Smithy (\$4)\n…',
                alignLabelWithHint: true,
                errorText: hasInput && !isValid
                    ? 'Paste 10 cards or a valid share code.'
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // Live validation feedback
            if (hasInput)
              _ParsePreview(
                parsed: _parsed,
                isValid: isValid,
                isShareCode: _isShareCode,
              ),

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
  final bool isShareCode;

  const _ParsePreview({
    required this.parsed,
    required this.isValid,
    required this.isShareCode,
  });

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
                isShareCode
                    ? 'Share code found — ready to import'
                    : isValid
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
          if (!isShareCode && parsed.isNotEmpty) ...[
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
