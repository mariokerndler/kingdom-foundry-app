import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/config_provider.dart';
import '../../utils/app_theme.dart';
import '../common/section_header.dart';

class RulesTab extends ConsumerWidget {
  const RulesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules    = ref.watch(configProvider).rules;
    final notifier = ref.read(configProvider.notifier);
    final hasRules = rules.hasActiveRules;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        SectionHeader(
          title:    'Exclusions',
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
          icon:     Icons.shield_outlined,
          label:    'No Attack cards',
          detail:   'Removes every card with the Attack type.',
          value:    rules.noAttacks,
          onChange: notifier.setNoAttacks,
        ),
        _RuleTile(
          icon:     Icons.hourglass_empty_rounded,
          label:    'No Duration cards',
          detail:   'Removes Stay-in-Play (orange banner) cards.',
          value:    rules.noDuration,
          onChange: notifier.setNoDuration,
        ),
        _RuleTile(
          icon:     Icons.science_outlined,
          label:    'No Potion-cost cards',
          detail:   'Skips cards requiring the Alchemy Potion.',
          value:    rules.noPotions,
          onChange: notifier.setNoPotions,
        ),
        _RuleTile(
          icon:     Icons.credit_card_off_outlined,
          label:    'No Debt cards',
          detail:   'Skips cards with a Debt (hex token) cost.',
          value:    rules.noDebt,
          onChange: notifier.setNoDebt,
        ),

        const _Divider(),
        const SectionHeader(
          title:    'Requirements',
          subtitle: 'Guarantee certain card types appear.',
        ),

        _RuleTile(
          icon:     Icons.shopping_cart_outlined,
          label:    'Require a +Buy card',
          detail:   'At least one card that grants +Buy.',
          value:    rules.requirePlusBuy,
          onChange: notifier.setRequirePlusBuy,
        ),
        _RuleTile(
          icon:     Icons.delete_outline_rounded,
          label:    'Require a Trashing card',
          detail:   'At least one card that can trash cards.',
          value:    rules.requireTrashing,
          onChange: notifier.setRequireTrashing,
        ),
        _RuleTile(
          icon:     Icons.account_tree_outlined,
          label:    'Require a Village',
          detail:   'At least one card granting +2 Actions.',
          value:    rules.requireVillage,
          onChange: notifier.setRequireVillage,
        ),

        const _Divider(),
        const SectionHeader(
          title:    'Cost Limit',
          subtitle: 'Cap the maximum coin cost of any kingdom card.',
        ),

        _MaxCostRow(
          currentMax: rules.maxCost,
          onChange:   notifier.setMaxCost,
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
  final String   label;
  final String   detail;
  final bool     value;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color:        value
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.cardSurface,
        border:       Border.all(
          color: value ? AppColors.goldDark : AppColors.divider,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        secondary: Icon(icon,
            size:  20,
            color: value ? AppColors.gold : AppColors.parchmentDim),
        title: Text(
          label,
          style: TextStyle(
            color:      value ? AppColors.parchment : AppColors.parchmentDim,
            fontWeight: value ? FontWeight.w500 : FontWeight.w400,
            fontSize:   14,
          ),
        ),
        subtitle: Text(
          detail,
          style: const TextStyle(color: AppColors.parchmentDim, fontSize: 12),
        ),
        value:     value,
        onChanged: onChange,
        dense:     true,
      ),
    );
  }
}

// ── Max cost slider row ────────────────────────────────────────────────────

class _MaxCostRow extends StatelessWidget {
  final int?             currentMax;
  final ValueChanged<int?> onChange;

  const _MaxCostRow({required this.currentMax, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final active = currentMax != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:        active
              ? AppColors.gold.withValues(alpha: 0.08)
              : AppColors.cardSurface,
          border:       Border.all(
            color: active ? AppColors.goldDark : AppColors.divider,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: Icon(Icons.paid_outlined,
                  size:  20,
                  color: active ? AppColors.gold : AppColors.parchmentDim),
              title: Text(
                active ? 'Max cost: \$$currentMax' : 'Enable max cost',
                style: TextStyle(
                  color:      active ? AppColors.parchment : AppColors.parchmentDim,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  fontSize:   14,
                ),
              ),
              subtitle: const Text(
                'Exclude cards that cost more than this.',
                style: TextStyle(color: AppColors.parchmentDim, fontSize: 12),
              ),
              value:     active,
              onChanged: (v) => onChange(v ? 6 : null),
              dense:     true,
            ),
            if (active) ...[
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor:   AppColors.gold,
                  inactiveTrackColor: AppColors.divider,
                  thumbColor:         AppColors.gold,
                  overlayColor:       AppColors.gold.withValues(alpha: 0.12),
                  valueIndicatorColor: AppColors.cardSurface,
                  valueIndicatorTextStyle:
                      const TextStyle(color: AppColors.parchment),
                ),
                child: Slider(
                  min:        2,
                  max:        8,
                  divisions:  6,
                  value:      currentMax!.toDouble(),
                  label:      '\$$currentMax',
                  onChanged:  (v) => onChange(v.round()),
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
                                ? AppColors.gold
                                : AppColors.parchmentDim,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVE RULES',
            style: TextStyle(
              color:         AppColors.gold,
              fontSize:      10,
              fontWeight:    FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing:    6,
            runSpacing: 6,
            children: descriptions
                .map((d) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        AppColors.goldDark.withValues(alpha: 0.15),
                        border:       Border.all(color: AppColors.goldDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d,
                        style: const TextStyle(
                          color:    AppColors.gold,
                          fontSize: 12,
                        ),
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
