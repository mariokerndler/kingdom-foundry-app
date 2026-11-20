import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/setup_exception.dart';
import '../models/game_vibe_preset.dart';
import '../models/kingdom_card.dart';
import '../models/share_payload.dart';
import '../models/teaching_kingdom.dart';
import '../providers/card_data_providers.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/translation_provider.dart';
import '../screens/results_screen.dart';
import '../utils/app_theme.dart';
import '../utils/open_web_page.dart';
import '../widgets/common/history_sheet.dart';
import '../widgets/common/player_count_bar.dart';
import '../widgets/screens/card_ban_list.dart';
import '../widgets/screens/expansion_picker.dart';
import '../widgets/screens/rules_section.dart';

// ── Shared page-transition route defined in results_screen.dart ────────────

// ── Screen ─────────────────────────────────────────────────────────────────

class ConfigurationScreen extends ConsumerStatefulWidget {
  const ConfigurationScreen({super.key, this.onOpenResults});

  final VoidCallback? onOpenResults;

  @override
  ConsumerState<ConfigurationScreen> createState() =>
      _ConfigurationScreenState();
}

enum _ConfigTab { expansions, rules, bans }

class _ConfigurationScreenState extends ConsumerState<ConfigurationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _ConfigTab.values.length, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
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

    final config = ref.watch(configProvider);
    final status = ref.watch(generationStatusProvider);
    final error = ref.watch(generationErrorProvider);
    final reason = ref.watch(generationFailureReasonProvider);
    final isLoading = status == GenerationStatus.loading;
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useWideLayout = width >= 1200 && textScale <= 1.15;
    final useScrollableTabs = width < 420 || textScale > 1.15;
    final actions = _appActions(config, isLoading);

    if (useWideLayout) {
      return Scaffold(
        appBar: AppBar(
          title: const _AppTitle(),
          actions: actions,
        ),
        body: _WideConfigurationBody(
          selectedIndex: _tabController.index,
          onTabSelected: (index) => _jumpToTab(_ConfigTab.values[index]),
          errorBanner: status == GenerationStatus.error && error != null
              ? _ConfigurationErrorBanner(
                  message: error,
                  reason: reason,
                  onReview: () => _jumpToTab(_tabForReason(reason)),
                  onDismiss: () => clearGenerationFeedback(ref),
                )
              : null,
          generatePanel: _GeneratePanel(
            isLoading: isLoading,
            importing: _importing,
            onGenerate: () => _generate(context, ref),
            onFirstGame: _showFirstGame,
            onReview: (reason) => _jumpToTab(_tabForReason(reason)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const _AppTitle(),
        actions: actions,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: useScrollableTabs,
          tabs: const [
            Tab(icon: Icon(Icons.library_books_outlined), text: 'Expansions'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Rules'),
            Tab(icon: Icon(Icons.style_outlined), text: 'Catalogue'),
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
        importing: _importing,
        onGenerate: () => _generate(context, ref),
        onFirstGame: _showFirstGame,
        onReview: (reason) => _jumpToTab(_tabForReason(reason)),
      ),
    );
  }

  List<Widget> _appActions(ConfigState config, bool isLoading) => [
        PopupMenuButton<String>(
          tooltip: 'Legal information',
          popUpAnimationStyle: AppMotion.menu(context),
          icon: const Icon(Icons.info_outline_rounded),
          onSelected: openWebPage,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'impressum.html',
              child: Text('Impressum'),
            ),
            PopupMenuItem(
              value: 'privacy.html',
              child: Text('Privacy'),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Open kingdom library',
          onPressed: isLoading
              ? null
              : () => showHistorySheet(context, ref,
                  onOpenResults: widget.onOpenResults),
          icon: const Icon(Icons.collections_bookmark_rounded),
        ),
        IconButton(
          tooltip: 'Import kingdom',
          onPressed: isLoading ? null : () => _showImportDialog(context, ref),
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
      ];

  void _handleTabChanged() {
    if (mounted) setState(() {});
  }

  void _jumpToTab(_ConfigTab tab) {
    if (_tabController.index == tab.index) return;
    _tabController.animateTo(tab.index,
        duration: AppMotion.duration(context, 220));
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

  Future<void> _generate(BuildContext context, WidgetRef ref,
      {TeachingKingdom? teaching, GameVibePreset? preset}) async {
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
    if (teaching == null &&
        preset == null &&
        config.rules.costCurve.enabled &&
        !config.rules.costCurve.isValid) {
      setGenerationFeedback(
        ref,
        message:
            'Complete the cost curve so it assigns exactly 10 kingdom slots before generating.',
      );
      _jumpToTab(_ConfigTab.rules);
      return;
    }

    HapticFeedback.mediumImpact();
    final success =
        await generateKingdom(ref, teaching: teaching, presetOverride: preset);

    if (!context.mounted) return;

    if (success) {
      _openResults();
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

  Future<void> _showFirstGame() async {
    final List<KingdomCard> cards;
    try {
      cards = await ref.read(allCardsProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not load the teaching kingdoms.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final config = ref.read(configProvider);
    final available = teachingKingdoms
        .where((board) => resolveTeachingKingdom(board, cards, config) != null)
        .toList();
    final choice =
        await showDialog<({TeachingKingdom? teaching, GameVibePreset? preset})>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Set up your first game'),
        content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Choose a fixed teaching kingdom or roll a board with beginner rules. Your saved setup settings stay in place.'),
                const SizedBox(height: 12),
                if (available.isEmpty)
                  const Text(
                      'No teaching kingdoms match your selected expansions and bans.'),
                for (final board in available)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(board.name),
                    subtitle: Text(board.lesson),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        Navigator.pop(context, (teaching: board, preset: null)),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Roll Beginner Friendly'),
                  subtitle: const Text(
                      'Prefers simple cards, leaves out Curse givers, and uses at most one Attack pile.'),
                  trailing: const Icon(Icons.casino_outlined),
                  onTap: () => Navigator.pop(context, (
                    teaching: null,
                    preset: GameVibePresets.byId('beginner_friendly')
                  )),
                ),
              ],
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'))
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _generate(context, ref,
        teaching: choice.teaching, preset: choice.preset);
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );

    if (text == null || !context.mounted) return;

    HapticFeedback.mediumImpact();
    await _importText(context, ref, text);
  }

  Future<void> _importText(
      BuildContext context, WidgetRef ref, String text) async {
    setState(() => _importing = true);
    final success = await importKingdom(ref, text);

    if (!context.mounted) return;
    setState(() => _importing = false);

    if (success) {
      _openResults();
    } else {
      final error = ref.read(generationErrorProvider) ?? 'Unknown error.';
      final reason = ref.read(generationFailureReasonProvider);
      _showErrorDialog(context, error, reason);
    }
  }

  void _openResults() {
    final onOpenResults = widget.onOpenResults;
    if (onOpenResults != null) {
      onOpenResults();
    } else {
      Navigator.of(context).push(buildResultsRoute());
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

class _WideConfigurationBody extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Widget? errorBanner;
  final Widget generatePanel;

  const _WideConfigurationBody({
    required this.selectedIndex,
    required this.onTabSelected,
    required this.errorBanner,
    required this.generatePanel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onTabSelected,
            labelType: NavigationRailLabelType.all,
            minWidth: 116,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books_rounded),
                label: Text('Expansions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_rounded),
                label: Text('Rules'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.style_outlined),
                selectedIcon: Icon(Icons.style_rounded),
                label: Text('Catalogue'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const PlayerCountBar(),
              if (errorBanner != null) errorBanner!,
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1680),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: selectedIndex,
                            children: const [
                              ExpansionPickerTab(),
                              RulesTab(),
                              CardBanListTab(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 420,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: generatePanel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── App title ──────────────────────────────────────────────────────────────

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logoMode = cs.brightness == Brightness.dark ? 'dark' : 'light';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/crown-deal-$logoMode.png',
          width: 32,
          height: 32,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kingdom Foundry',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Kingdom Generator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.primary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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
      SetupFailureReason.requirementImpossible => (
          'A rule combination needs attention',
          'Review rules'
        ),
      SetupFailureReason.varietyImpossible => (
          'Expansion variety needs attention',
          'Review expansions'
        ),
      SetupFailureReason.poolTooSmall => (
          'Card pool is too small',
          'Review setup'
        ),
      null => ('Setup needs attention', 'Review setup'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
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
  final bool importing;
  final VoidCallback onGenerate;
  final VoidCallback onFirstGame;
  final ValueChanged<SetupFailureReason> onReview;

  const _GeneratePanel({
    required this.isLoading,
    required this.importing,
    required this.onGenerate,
    required this.onFirstGame,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pool = ref.watch(selectedPoolCountProvider);
    final count = pool.valueOrNull;
    final conflict = ref.watch(selectedPoolConflictProvider);
    final status = switch (count) {
      null => pool.hasError ? 'Card pool unavailable' : 'Loading card pool…',
      < 10 => '$count eligible · At least 10 needed',
      _ => '$count eligible piles',
    };

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child:
                      Text('Current setup', style: theme.textTheme.titleSmall)),
              TextButton(
                  onPressed: isLoading ? null : onFirstGame,
                  child: const Text('First game')),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: count != null && count < 10
                    ? cs.error
                    : cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (conflict != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(conflict.message,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error)),
              TextButton(
                onPressed: () => onReview(conflict.reason),
                child: Text(
                    conflict.reason == SetupFailureReason.requirementImpossible
                        ? 'Review rules'
                        : 'Review expansions'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: Semantics(
                liveRegion: isLoading,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onGenerate,
                  icon: isLoading && !MediaQuery.disableAnimationsOf(context)
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Icon(isLoading
                          ? Icons.hourglass_top_rounded
                          : Icons.casino_rounded),
                  label: Text(isLoading
                      ? (importing
                          ? 'Importing kingdom…'
                          : 'Generating kingdom…')
                      : 'Generate kingdom'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Import dialog ──────────────────────────────────────────────────────────

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    // Pre-fill if the clipboard already contains a kingdom list.
    Clipboard.getData('text/plain').then((data) {
      if (!mounted || _ctrl.text.isNotEmpty || data?.text == null) return;
      final names = parseKingdomText(data!.text!);
      if (names.length == 10 || SharePayload.looksLikeShareCode(data.text!)) {
        _ctrl.text = data.text!;
      }
    }, onError: (Object _) {});
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(allCardsProvider);
    final packs = ref.watch(translationPacksProvider);
    final hasInput = _ctrl.text.trim().isNotEmpty;
    var isValid = false;
    var feedback = 'Loading the card catalogue…';
    if (hasInput && SharePayload.looksLikeShareCode(_ctrl.text)) {
      isValid = true;
      feedback = 'Share code found. Import will validate its cards.';
    } else if (hasInput && catalogue.hasError) {
      feedback = 'Could not load the card catalogue.';
    } else if (hasInput && catalogue.hasValue && !packs.isLoading) {
      try {
        final selection = resolveSetupText(catalogue.requireValue, _ctrl.text,
            packs: packs.valueOrNull ?? const []);
        final landscapeCount = selection.landscapes.length;
        isValid = true;
        feedback = landscapeCount == 0
            ? '10 piles recognized.'
            : '10 piles and $landscapeCount landscape cards recognized.';
      } on FormatException catch (error) {
        feedback = error.message;
      }
    }

    return AlertDialog(
      scrollable: true,
      title: const Text('Import a kingdom'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              maxLines: 8,
              minLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Kingdom list, share code, or link',
                hintText: 'Village\nSmithy\n…',
                alignLabelWithHint: true,
              ),
            ),
            if (hasInput) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(feedback,
                    style: TextStyle(
                      color: isValid
                          ? AppColors.success(Theme.of(context).colorScheme)
                          : Theme.of(context).colorScheme.error,
                    )),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isValid ? () => Navigator.pop(context, _ctrl.text) : null,
          child: const Text('Import kingdom'),
        ),
      ],
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
          Icon(icon, color: Theme.of(context).colorScheme.error, size: 22),
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
