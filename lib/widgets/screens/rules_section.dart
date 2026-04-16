import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cost_curve_rule.dart';
import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';
import '../common/section_header.dart';

class RulesTab extends ConsumerStatefulWidget {
  const RulesTab({super.key});

  @override
  ConsumerState<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends ConsumerState<RulesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final rules = ref.watch(configProvider).rules;
    final notifier = ref.read(configProvider.notifier);
    final hasRules = rules.hasActiveRules;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        SectionHeader(
          title: 'Exclusions',
          subtitle: 'Remove card types from the pool entirely.',
          trailing: hasRules
              ? TextButton(
                  onPressed: notifier.resetRules,
                  child: const Text(
                    'Reset all',
                    style: TextStyle(color: AppColors.errorRed, fontSize: 13),
                  ),
                )
              : null,
        ),

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
          label: 'No Travellers',
          detail:
              'Removes Page, Peasant, Hermit, and Urchin to skip set-aside chains.',
          value: rules.noTravellers,
          onChange: notifier.setNoTravellers,
        ),

        const _Divider(),
        const SectionHeader(
          title: 'Landscape Cards',
          subtitle: 'Events, Landmarks, Projects, Ways, Allies and Traits.',
        ),

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

        const _Divider(),
        const SectionHeader(
          title: 'Requirements',
          subtitle: 'Guarantee certain card types appear.',
        ),

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

        const _Divider(),
        const SectionHeader(
          title: 'Cost Limit',
          subtitle: 'Cap the maximum coin cost of any kingdom card.',
        ),

        _MaxCostRow(
          currentMax: rules.maxCost,
          onChange: notifier.setMaxCost,
        ),

        const _Divider(),
        const SectionHeader(
          title: 'Attack Limit',
          subtitle: 'Cap how many Attack cards can appear in the kingdom.',
        ),

        _MaxAttacksRow(
          currentMax: rules.maxAttacks,
          onChange: notifier.setMaxAttacks,
        ),

        const _Divider(),
        SectionHeader(
          title: 'Cost Curve',
          subtitle: 'Prefer kingdoms that match your target cost spread.',
          trailing: rules.costCurve.enabled
              ? TextButton(
                  onPressed: notifier.resetCostCurve,
                  child: const Text(
                    'Reset curve',
                    style: TextStyle(fontSize: 13),
                  ),
                )
              : null,
        ),

        _CostCurveEditor(
          rule: rules.costCurve,
          onEnabledChanged: notifier.setCostCurveEnabled,
          onCheapChanged: notifier.setCostCurveCheapCount,
          onThreeChanged: notifier.setCostCurveThreeCount,
          onFourChanged: notifier.setCostCurveFourCount,
          onFiveChanged: notifier.setCostCurveFiveCount,
          onSixPlusChanged: notifier.setCostCurveSixPlusCount,
        ),

        const _Divider(),
        const SectionHeader(
          title: 'Display',
          subtitle:
              'Control what extra guidance appears on the results screen.',
        ),

        _RuleTile(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Show strategy tips',
          detail:
              'Display heuristic archetypes and strategy guidance on results.',
          value: rules.showStrategyTips,
          onChange: notifier.setShowStrategyTips,
        ),

        // Active rules summary
        if (hasRules) ...[
          const _Divider(),
          _ActiveRulesSummary(descriptions: rules.activeRuleDescriptions),
        ],
      ],
    );
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
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: value ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
        border: Border.all(
          color: value ? cs.primary : cs.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        secondary: Icon(icon,
            size: 20, color: value ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          label,
          style: TextStyle(
            color: value ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: value ? FontWeight.w500 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          detail,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        value: value,
        onChanged: onChange,
        dense: true,
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
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: Icon(Icons.show_chart_rounded,
                  size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
              title: Text(
                'Prefer a cost curve',
                style: TextStyle(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Bias generation toward cheap, mid-cost, and expensive slots you choose.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              value: active,
              onChanged: onEnabledChanged,
              dense: true,
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
                    color: isValid ? cs.onSurface : AppColors.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isValid)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Finish assigning all 10 kingdom slots before generating.',
                    style: TextStyle(
                      color: AppColors.errorRed,
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
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: Icon(Icons.paid_outlined,
                  size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
              title: Text(
                active ? 'Max cost: \$$currentMax' : 'Enable max cost',
                style: TextStyle(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Exclude cards that cost more than this.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              value: active,
              onChanged: (v) => onChange(v ? 6 : null),
              dense: true,
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
      duration: const Duration(milliseconds: 180),
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
                  ? AppColors.errorRed // keep — signals invalid zero count
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
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: enabled ? cs.surfaceContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(6),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? cs.onSurface : cs.outlineVariant,
          ),
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
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
          border: Border.all(color: active ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: Icon(Icons.shield_outlined,
                  size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
              title: Text(
                active ? 'Max attacks: $currentMax' : 'Enable attack limit',
                style: TextStyle(
                  color: active ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Limit how many Attack cards appear in the kingdom.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              value: active,
              onChanged: (v) => onChange(v ? 2 : null),
              dense: true,
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
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: currentMax!.toDouble(),
                  label: '$currentMax',
                  onChanged: (v) => onChange(v.round()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [1, 2, 3, 4, 5]
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
  const _ActiveRulesSummary({required this.descriptions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE RULES',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: descriptions
                .map((d) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.10),
                        border: Border.all(color: cs.primary),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(color: cs.primary, fontSize: 12),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 24, indent: 20, endIndent: 20);
}
