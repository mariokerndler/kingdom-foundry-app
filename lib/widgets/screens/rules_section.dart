import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/setup_exception.dart';
import '../../models/cost_curve_rule.dart';
import '../../models/game_vibe_preset.dart';
import '../../models/setup_rules.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../providers/generation_provider.dart';
import '../../providers/translation_provider.dart';
import '../../services/translation_service.dart';
import '../../utils/app_theme.dart';
import '../common/ui_primitives.dart';

class RulesTab extends ConsumerStatefulWidget {
  const RulesTab({super.key});

  @override
  ConsumerState<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends ConsumerState<RulesTab>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController;
  late final Map<_RuleSection, bool> _expandedSections;
  late final Map<_RuleSection, GlobalKey> _sectionKeys;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _expandedSections = {
      for (final section in _RuleSection.values)
        section: switch (section) {
          _RuleSection.gameVibe => true,
          _RuleSection.exclusions => true,
          _RuleSection.landscapes => false,
          _RuleSection.requirements => true,
          _RuleSection.costLimit => false,
          _RuleSection.attackLimit => false,
          _RuleSection.costCurve => true,
          _RuleSection.display => true,
        },
    };
    _sectionKeys = {
      for (final section in _RuleSection.values) section: GlobalKey(),
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<SetupFailureReason?>(generationFailureReasonProvider, (_, next) {
      if (next == null) return;
      switch (next) {
        case SetupFailureReason.requirementImpossible:
          _focusSection(_RuleSection.requirements);
        case SetupFailureReason.varietyImpossible:
        case SetupFailureReason.poolTooSmall:
          _focusSection(_RuleSection.exclusions);
      }
    });

    final config = ref.watch(configProvider);
    final rules = config.rules;
    final notifier = ref.read(configProvider.notifier);
    final hasRules = rules.hasActiveRules;
    final preset = GameVibePresets.byId(config.selectedPresetId);
    final hasPreset = preset.id != GameVibePresets.noneId;
    final rulesJson = jsonEncode(rules.toJson());
    final isCustomized = hasPreset &&
        rulesJson != jsonEncode(preset.rulesAppliedTo(rules).toJson());
    final canReset =
        hasPreset || rulesJson != jsonEncode(const SetupRules().toJson());

    void changeSettings(VoidCallback change, String message) {
      final before = ref.read(configProvider);
      change();
      final after = ref.read(configProvider);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (!mounted) return;
                final current = ref.read(configProvider);
                if (identical(current.rules, after.rules) &&
                    current.selectedPresetId == after.selectedPresetId) {
                  notifier.restoreRules(before.rules, before.selectedPresetId);
                }
              }),
        ));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (hasRules) ...[
          _ActiveRulesSummary(
            descriptions: rules.activeRuleDescriptions,
            onDescriptionTap: (description) =>
                _focusSection(_sectionForDescription(description)),
          ),
          _RulesConflictHint(rules: rules),
        ],
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.gameVibe],
          title: 'Game Vibe',
          subtitle:
              'Apply a curated preset before fine-tuning the rules below.',
          expanded: _expandedSections[_RuleSection.gameVibe]!,
          onChanged: (value) => _setExpanded(_RuleSection.gameVibe, value),
          child: Column(children: [
            _PresetSelector(
              selectedPresetId: config.selectedPresetId,
              customized: isCustomized,
              onChanged: (id) => changeSettings(
                  () => notifier.setSelectedPresetId(id),
                  id == GameVibePresets.noneId
                      ? 'Vibe removed. Your rules were kept.'
                      : 'Preset rules applied.'),
            ),
            _RuleTile(
              icon: Icons.history_rounded,
              label: 'Prefer fresh piles',
              detail:
                  'Favors piles outside the last three boards while respecting your bans and rules.',
              value: config.preferFreshPiles,
              onChange: notifier.setPreferFreshPiles,
            ),
          ]),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.exclusions],
          title: 'Exclusions',
          subtitle: 'Remove card types from the pool entirely.',
          expanded: _expandedSections[_RuleSection.exclusions]!,
          onChanged: (value) => _setExpanded(_RuleSection.exclusions, value),
          trailing: canReset
              ? TextButton(
                  onPressed: () => changeSettings(
                      notifier.resetRules, 'Rules and vibe reset.'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Reset all'),
                )
              : null,
          child: Column(
            children: [
              _RuleTile(
                icon: Icons.shield_outlined,
                label: 'No Attack cards',
                detail: 'Removes every card with the Attack type.',
                value: rules.noAttacks,
                onChange: notifier.setNoAttacks,
              ),
              _RuleTile(
                icon: Icons.hourglass_empty_rounded,
                label: 'No Duration cards',
                detail: 'Removes Stay-in-Play (orange banner) cards.',
                value: rules.noDuration,
                onChange: notifier.setNoDuration,
              ),
              _RuleTile(
                icon: Icons.science_outlined,
                label: 'No Potion-cost cards',
                detail: 'Skips cards requiring the Alchemy Potion.',
                value: rules.noPotions,
                onChange: notifier.setNoPotions,
              ),
              _RuleTile(
                icon: Icons.credit_card_off_outlined,
                label: 'No Debt cards',
                detail: 'Skips cards with a Debt (hex token) cost.',
                value: rules.noDebt,
                onChange: notifier.setNoDebt,
              ),
              _RuleTile(
                icon: Icons.sentiment_very_dissatisfied_outlined,
                label: 'No Curse-givers',
                detail: 'Removes cards that hand out Curse cards (e.g. Witch).',
                value: rules.noCursers,
                onChange: notifier.setNoCursers,
              ),
              _RuleTile(
                icon: Icons.swap_horiz_rounded,
                label: 'No exchange chains',
                detail:
                    'Removes Traveller and exchange-chain piles, including Page, Peasant, Hermit, Urchin, and Vampire.',
                value: rules.noTravellers,
                onChange: notifier.setNoTravellers,
              ),
            ],
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.landscapes],
          title: 'Landscape Cards',
          subtitle: 'Events, Landmarks, Projects, Ways, Allies and Traits.',
          expanded: _expandedSections[_RuleSection.landscapes]!,
          onChanged: (value) => _setExpanded(_RuleSection.landscapes, value),
          child: Column(
            children: [
              _RuleTile(
                icon: Icons.map_outlined,
                label: 'Include landscape cards',
                detail: 'Draw Events, Projects, etc. from owned expansions.',
                value: rules.includeLandscape,
                onChange: notifier.setIncludeLandscape,
              ),
              if (rules.includeLandscape) ...[
                _LandscapeCountTile(
                  icon: Icons.bolt_outlined,
                  label: 'Events',
                  value: rules.landscapeEvents,
                  max: 4,
                  onChange: notifier.setLandscapeEvents,
                ),
                _LandscapeCountTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Projects',
                  value: rules.landscapeProjects,
                  max: 4,
                  onChange: notifier.setLandscapeProjects,
                ),
                _LandscapeCountTile(
                  icon: Icons.landscape_outlined,
                  label: 'Landmarks',
                  value: rules.landscapeLandmarks,
                  max: 3,
                  onChange: notifier.setLandscapeLandmarks,
                ),
                _LandscapeCountTile(
                  icon: Icons.route_outlined,
                  label: 'Ways',
                  value: rules.landscapeWays,
                  max: 4,
                  onChange: notifier.setLandscapeWays,
                ),
                _LandscapeCountTile(
                  icon: Icons.groups_outlined,
                  label: 'Allies',
                  value: rules.landscapeAllies,
                  max: 3,
                  onChange: notifier.setLandscapeAllies,
                ),
                _LandscapeCountTile(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Traits',
                  value: rules.landscapeTraits,
                  max: 4,
                  onChange: notifier.setLandscapeTraits,
                ),
              ],
            ],
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.requirements],
          title: 'Requirements',
          subtitle: 'Guarantee certain card types appear.',
          expanded: _expandedSections[_RuleSection.requirements]!,
          onChanged: (value) => _setExpanded(_RuleSection.requirements, value),
          child: Column(
            children: [
              _RuleTile(
                icon: Icons.shopping_cart_outlined,
                label: 'Require a +Buy card',
                detail: 'At least one card that grants +Buy.',
                value: rules.requirePlusBuy,
                onChange: notifier.setRequirePlusBuy,
              ),
              _RuleTile(
                icon: Icons.delete_outline_rounded,
                label: 'Require a Trashing card',
                detail: 'At least one card that can trash cards.',
                value: rules.requireTrashing,
                onChange: notifier.setRequireTrashing,
              ),
              _RuleTile(
                icon: Icons.account_tree_outlined,
                label: 'Require a Village',
                detail: 'At least one card granting +2 Actions.',
                value: rules.requireVillage,
                onChange: notifier.setRequireVillage,
              ),
              _RuleTile(
                icon: Icons.style_outlined,
                label: 'Require card draw',
                detail: 'At least one card that draws additional cards.',
                value: rules.requireDraw,
                onChange: notifier.setRequireDraw,
              ),
              _RuleTile(
                icon: Icons.security_outlined,
                label: 'Auto-Reaction',
                detail:
                    'If Attacks are present, guarantee at least one Reaction card.',
                value: rules.requireReactionIfAttacks,
                onChange: notifier.setRequireReactionIfAttacks,
              ),
            ],
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.costLimit],
          title: 'Cost Limit',
          subtitle: 'Cap the maximum coin cost of any kingdom card.',
          expanded: _expandedSections[_RuleSection.costLimit]!,
          onChanged: (value) => _setExpanded(_RuleSection.costLimit, value),
          child: _MaxCostRow(
            currentMax: rules.maxCost,
            onChange: notifier.setMaxCost,
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.attackLimit],
          title: 'Attack Limit',
          subtitle: 'Cap how many Attack cards can appear in the kingdom.',
          expanded: _expandedSections[_RuleSection.attackLimit]!,
          onChanged: (value) => _setExpanded(_RuleSection.attackLimit, value),
          child: _MaxAttacksRow(
            currentMax: rules.maxAttacks,
            onChange: notifier.setMaxAttacks,
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.costCurve],
          title: 'Cost Curve',
          subtitle: 'Prefer kingdoms that match your target cost spread.',
          expanded: _expandedSections[_RuleSection.costCurve]!,
          onChanged: (value) => _setExpanded(_RuleSection.costCurve, value),
          trailing: rules.costCurve.enabled
              ? TextButton(
                  onPressed: notifier.resetCostCurve,
                  child: const Text('Reset curve'),
                )
              : null,
          child: _CostCurveEditor(
            rule: rules.costCurve,
            onEnabledChanged: notifier.setCostCurveEnabled,
            onCheapChanged: notifier.setCostCurveCheapCount,
            onThreeChanged: notifier.setCostCurveThreeCount,
            onFourChanged: notifier.setCostCurveFourCount,
            onFiveChanged: notifier.setCostCurveFiveCount,
            onSixPlusChanged: notifier.setCostCurveSixPlusCount,
          ),
        ),
        _SectionAccordion(
          key: _sectionKeys[_RuleSection.display],
          title: 'Display',
          subtitle:
              'Control what extra guidance appears on the results screen.',
          expanded: _expandedSections[_RuleSection.display]!,
          onChanged: (value) => _setExpanded(_RuleSection.display, value),
          child: Column(
            children: [
              _RuleTile(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Show strategy tips',
                detail:
                    'Display heuristic archetypes and strategy guidance on results.',
                value: rules.showStrategyTips,
                onChange: notifier.setShowStrategyTips,
              ),
              _LanguageSelector(
                selectedLanguageCode: config.selectedLanguageCode,
                onChanged: notifier.setSelectedLanguageCode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _setExpanded(_RuleSection section, bool expanded) {
    setState(() => _expandedSections[section] = expanded);
  }

  void _focusSection(_RuleSection section) {
    if (!_expandedSections[section]!) {
      setState(() => _expandedSections[section] = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _sectionKeys[section]!.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: AppMotion.duration(targetContext, 260),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    });
  }

  _RuleSection _sectionForDescription(String description) {
    if (description.startsWith('Max cost')) return _RuleSection.costLimit;
    if (description.startsWith('Max ') && description.contains('attack')) {
      return _RuleSection.attackLimit;
    }
    if (description.startsWith('No ')) return _RuleSection.exclusions;
    if (description.startsWith('Events:') ||
        description.startsWith('Projects:') ||
        description.startsWith('Landmarks:') ||
        description.startsWith('Ways:') ||
        description.startsWith('Allies:') ||
        description.startsWith('Traits:') ||
        description == 'No landscape cards') {
      return _RuleSection.landscapes;
    }
    if (description.startsWith('Must include') ||
        description == 'Auto-Reaction') {
      return _RuleSection.requirements;
    }
    if (description.contains('curve')) return _RuleSection.costCurve;
    if (description == 'Hide strategy tips') return _RuleSection.display;
    return _RuleSection.exclusions;
  }
}

enum _RuleSection {
  gameVibe,
  exclusions,
  landscapes,
  requirements,
  costLimit,
  attackLimit,
  costCurve,
  display,
}

class _SectionAccordion extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final ValueChanged<bool> onChanged;
  final Widget child;
  final Widget? trailing;

  const _SectionAccordion({
    super.key,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onChanged,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded
                ? cs.primary.withValues(alpha: 0.35)
                : cs.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(!expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: expanded
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.duration(context, 220),
              curve: Curves.easeOut,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: child,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesConflictHint extends StatelessWidget {
  final SetupRules rules;

  const _RulesConflictHint({required this.rules});

  @override
  Widget build(BuildContext context) {
    final warnings = <String>[
      if (rules.noAttacks && rules.requireReactionIfAttacks)
        'Auto-Reaction may never matter while Attack cards are excluded.',
      if (rules.noAttacks && rules.maxAttacks != null)
        'Attack limit is redundant while Attack cards are excluded.',
      if (rules.costCurve.enabled && !rules.costCurve.isValid)
        'Finish assigning all 10 cost-curve slots before generating.',
      if (rules.activeRuleDescriptions.length >= 6)
        'Many active constraints can shrink the card pool and cause failed rolls.',
    ];

    if (warnings.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rule Notes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $warning',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  final String selectedPresetId;
  final bool customized;
  final ValueChanged<String> onChanged;

  const _PresetSelector({
    required this.selectedPresetId,
    required this.customized,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presets = GameVibePresets.all.skip(1).toList();
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const horizontalPadding = 32.0;
        final available = constraints.maxWidth - horizontalPadding;
        final columns = textScale > 1.15
            ? 1
            : available >= 1080
                ? 4
                : available >= 760
                    ? 3
                    : available >= 500
                        ? 2
                        : 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var start = 0; start < presets.length; start += columns) ...[
                if (start > 0) const SizedBox(height: spacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: spacing),
                        Expanded(
                          child: start + column < presets.length
                              ? _buildCard(presets[start + column])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (selectedPresetId != GameVibePresets.noneId)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (customized) ...[
                      const Text('Customized'),
                      TextButton(
                        onPressed: () => onChanged(selectedPresetId),
                        child: const Text('Restore preset defaults'),
                      ),
                    ],
                    TextButton(
                      onPressed: () => onChanged(GameVibePresets.noneId),
                      child: const Text('Remove vibe'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(GameVibePreset preset) {
    final selected = preset.id == selectedPresetId;
    return _PresetCard(
      preset: preset,
      selected: selected,
      onTap: () => onChanged(selected ? GameVibePresets.noneId : preset.id),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final GameVibePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      label: '${preset.name} preset',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.10)
                  : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? cs.primary : cs.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  preset.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                const SizedBox(height: 10),
                Text(
                  selected
                      ? 'Preset active - tap again to remove vibe'
                      : 'Tap to apply defaults',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  final String selectedLanguageCode;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.selectedLanguageCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(translationPacksProvider);
    final pack = ref.watch(activeTranslationPackProvider).valueOrNull;
    final eligibleCards = ref.watch(selectedKingdomPoolProvider).valueOrNull;
    final translatedCount = eligibleCards
        ?.where((card) => pack?.lookup(card.id)?.isComplete == true)
        .length;
    return packsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: AppLoadingStrip(label: 'Loading translation packs...'),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: AppStateCard(
          icon: Icons.translate_rounded,
          title: 'Translation packs unavailable',
          message: 'Card languages could not be loaded right now.',
        ),
      ),
      data: (packs) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Language',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Use local translation packs for card names and rules text. Shared codes stay language-agnostic.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue:
                    packs.any((p) => p.languageCode == selectedLanguageCode)
                        ? selectedLanguageCode
                        : 'en',
                items: packs
                    .map(
                      (pack) => DropdownMenuItem(
                        value: pack.languageCode,
                        child: Text(pack.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
                decoration: const InputDecoration(
                  labelText: 'Preferred card language',
                ),
              ),
              if (pack != null &&
                  pack.languageCode != 'en' &&
                  translatedCount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '$translatedCount of ${eligibleCards!.length} eligible cards have translated names and rules. Missing translations use English.'),
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showTranslationImportDialog(context, ref),
                  icon: const Icon(Icons.translate_rounded, size: 16),
                  label: const Text('Import translation pack'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTranslationImportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final catalogue = ref.read(allCardsProvider).valueOrNull;
    if (catalogue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The card catalogue is unavailable.')),
      );
      return;
    }
    final cardIds = catalogue.map((card) => card.id).toSet();
    String? validationMessage(String value) {
      if (value.trim().isEmpty) {
        return 'Paste a translation pack JSON payload to continue.';
      }
      try {
        TranslationService.validatePack(value.trim(), cardIds);
        return null;
      } on FormatException catch (error) {
        return error.message;
      } catch (_) {
        return 'Expected translation names and rules text to be strings.';
      }
    }

    final rawJson = await showDialog<String>(
      context: context,
      builder: (context) {
        var input = '';
        String? errorText = validationMessage(input);
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            scrollable: true,
            title: const Text('Import Translation Pack'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste a JSON translation pack with a language code, label, and card map.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 14,
                    minLines: 6,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) => setState(() {
                      input = value;
                      errorText = validationMessage(input);
                    }),
                    decoration: InputDecoration(
                      labelText: 'Translation pack JSON',
                      helperText: 'Paste a full translation pack payload.',
                      hintText:
                          '{"languageCode":"fr","label":"Francais","cards":{...}}',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: errorText == null
                    ? () => Navigator.of(context).pop(input.trim())
                    : null,
                child: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );

    if (!context.mounted || rawJson == null || rawJson.isEmpty) return;

    try {
      await ref.read(translationServiceProvider).importPack(rawJson, cardIds);
      if (!context.mounted) return;
      ref.invalidate(translationPacksProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Translation pack imported')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not import translation pack'),
          ),
        );
      }
    }
  }
}

// ── Rule toggle tile ────────────────────────────────────────────────────────

class _RuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChange;

  const _RuleTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.duration(context, 180),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: value ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
        border: Border.all(
          color: value ? cs.primary : cs.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChange(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    icon,
                    size: 20,
                    color: value ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: value ? cs.onSurface : cs.onSurfaceVariant,
                          fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: value,
                  onChanged: onChange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdaptiveToggleHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AdaptiveToggleHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  icon,
                  size: 20,
                  color: value ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: value ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Max cost slider row ────────────────────────────────────────────────────

class _CostCurveEditor extends StatelessWidget {
  final CostCurveRule rule;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onCheapChanged;
  final ValueChanged<int> onThreeChanged;
  final ValueChanged<int> onFourChanged;
  final ValueChanged<int> onFiveChanged;
  final ValueChanged<int> onSixPlusChanged;

  const _CostCurveEditor({
    required this.rule,
    required this.onEnabledChanged,
    required this.onCheapChanged,
    required this.onThreeChanged,
    required this.onFourChanged,
    required this.onFiveChanged,
    required this.onSixPlusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = rule.enabled;
    final total = rule.totalSlots;
    final canIncrease = total < CostCurveRule.targetSlotCount;
    final isValid = rule.isValid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdaptiveToggleHeader(
              icon: Icons.show_chart_rounded,
              title: 'Prefer a cost curve',
              subtitle:
                  'Bias generation toward cheap, mid-cost, and expensive slots you choose.',
              value: active,
              onChanged: onEnabledChanged,
            ),
            if (active) ...[
              const Divider(height: 1),
              const SizedBox(height: 8),
              _CostCurveBucketRow(
                label: '<=2',
                value: rule.cheapCount,
                canIncrease: canIncrease,
                onChange: onCheapChanged,
              ),
              _CostCurveBucketRow(
                label: '3',
                value: rule.threeCount,
                canIncrease: canIncrease,
                onChange: onThreeChanged,
              ),
              _CostCurveBucketRow(
                label: '4',
                value: rule.fourCount,
                canIncrease: canIncrease,
                onChange: onFourChanged,
              ),
              _CostCurveBucketRow(
                label: '5',
                value: rule.fiveCount,
                canIncrease: canIncrease,
                onChange: onFiveChanged,
              ),
              _CostCurveBucketRow(
                label: '6+',
                value: rule.sixPlusCount,
                canIncrease: canIncrease,
                onChange: onSixPlusChanged,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Text(
                  'Assigned $total / ${CostCurveRule.targetSlotCount} slots',
                  style: TextStyle(
                    color: isValid
                        ? cs.onSurface
                        : Theme.of(context).colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isValid)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Finish assigning all 10 kingdom slots before generating.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _CostCurveBucketRow extends StatelessWidget {
  final String label;
  final int value;
  final bool canIncrease;
  final ValueChanged<int> onChange;

  const _CostCurveBucketRow({
    required this.label,
    required this.value,
    required this.canIncrease,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Target slots',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          _Stepper(
            value: value,
            min: 0,
            max: CostCurveRule.targetSlotCount,
            canIncrease: canIncrease,
            onChange: onChange,
          ),
        ],
      ),
    );
  }
}

class _MaxCostRow extends StatelessWidget {
  final int? currentMax;
  final ValueChanged<int?> onChange;

  const _MaxCostRow({required this.currentMax, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = currentMax != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdaptiveToggleHeader(
              icon: Icons.paid_outlined,
              title: active ? 'Max cost: \$$currentMax' : 'Enable max cost',
              subtitle:
                  'Exclude cards above this cost. A split pile is excluded '
                  'if any of its members exceeds the cap.',
              value: active,
              onChanged: (v) => onChange(v ? 6 : null),
            ),
            if (active) ...[
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outlineVariant,
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.12),
                  valueIndicatorColor: cs.surfaceContainer,
                  valueIndicatorTextStyle: TextStyle(color: cs.onSurface),
                ),
                child: Slider(
                  min: 2,
                  max: 8,
                  divisions: 6,
                  value: currentMax!.toDouble(),
                  label: '\$$currentMax',
                  onChanged: (v) => onChange(v.round()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [2, 3, 4, 5, 6, 7, 8]
                      .map((c) => Text('\$$c',
                          style: TextStyle(
                            fontSize: 11,
                            color: currentMax == c
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          )))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Landscape type count tile ──────────────────────────────────────────────

class _LandscapeCountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChange;

  const _LandscapeCountTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nonDefault = value != _default;

    return AnimatedContainer(
      duration: AppMotion.duration(context, 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: nonDefault
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainer,
        border: Border.all(color: nonDefault ? cs.primary : cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: nonDefault ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: nonDefault ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: nonDefault ? FontWeight.w500 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            _Stepper(value: value, min: 0, max: max, onChange: onChange),
          ],
        ),
      ),
    );
  }

  // Returns the "default" count for this tile based on the label.
  int get _default => switch (label) {
        'Events' => 2,
        'Projects' => 2,
        _ => 1,
      };
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final bool canIncrease;
  final ValueChanged<int> onChange;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    this.canIncrease = true,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onPressed: () => onChange(value - 1),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: value == 0
                  ? Theme.of(context)
                      .colorScheme
                      .error // keep — signals invalid zero count
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add_rounded,
          enabled: value < max && canIncrease,
          onPressed: () => onChange(value + 1),
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        size: 20,
        color: enabled ? cs.onSurface : cs.outlineVariant,
      ),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? cs.surfaceContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }
}

// ── Max attacks slider row ─────────────────────────────────────────────────

class _MaxAttacksRow extends StatelessWidget {
  final int? currentMax;
  final ValueChanged<int?> onChange;

  const _MaxAttacksRow({required this.currentMax, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = currentMax != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdaptiveToggleHeader(
              icon: Icons.shield_outlined,
              title:
                  active ? 'Max attacks: $currentMax' : 'Enable attack limit',
              subtitle: 'Limit how many Attack cards appear in the kingdom.',
              value: active,
              onChanged: (v) => onChange(v ? 2 : null),
            ),
            if (active) ...[
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: cs.primary,
                  inactiveTrackColor: cs.outlineVariant,
                  thumbColor: cs.primary,
                  overlayColor: cs.primary.withValues(alpha: 0.12),
                  valueIndicatorColor: cs.surfaceContainer,
                  valueIndicatorTextStyle: TextStyle(color: cs.onSurface),
                ),
                child: Slider(
                  min: 0,
                  max: 5,
                  divisions: 5,
                  value: currentMax!.toDouble(),
                  label: '$currentMax',
                  onChanged: (v) => onChange(v.round()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [0, 1, 2, 3, 4, 5]
                      .map((n) => Text('$n',
                          style: TextStyle(
                            fontSize: 11,
                            color: currentMax == n
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          )))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Active rules summary chip strip ───────────────────────────────────────

class _ActiveRulesSummary extends StatelessWidget {
  final List<String> descriptions;
  final ValueChanged<String>? onDescriptionTap;

  const _ActiveRulesSummary({
    required this.descriptions,
    this.onDescriptionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active rules',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: descriptions
                .map((d) => ActionChip(
                      label: Text(d),
                      onPressed: onDescriptionTap == null
                          ? null
                          : () => onDescriptionTap!(d),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
