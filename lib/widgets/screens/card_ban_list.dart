import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/card_type.dart';
import '../../models/expansion.dart';
import '../../models/kingdom_card.dart';
import '../../providers/card_data_providers.dart';
import '../../providers/config_provider.dart';
import '../../providers/translation_provider.dart';
import '../cards/kingdom_card_widget.dart';
import '../common/ui_primitives.dart';

class CardBanListTab extends ConsumerStatefulWidget {
  final List<KingdomCard>? replacementCards;
  final ValueChanged<String>? onSelectPile;
  final Map<String, String> replacementNotes;

  const CardBanListTab({super.key})
      : replacementCards = null,
        onSelectPile = null,
        replacementNotes = const {};

  const CardBanListTab.replacements(
      {super.key,
      required this.replacementCards,
      required this.onSelectPile,
      this.replacementNotes = const {}});

  @override
  ConsumerState<CardBanListTab> createState() => _CardBanListTabState();
}

class _CardBanListTabState extends ConsumerState<CardBanListTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _query = '';
  bool _ownedOnly = true;
  bool _bannedOnly = false;
  Expansion? _expansion;
  CardType? _type;
  int? _cost;
  CardRole? _role;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final config = ref.watch(configProvider);
    final pack = ref.watch(activeTranslationPackProvider).valueOrNull;
    final replacementCards = widget.replacementCards;
    final choosing = replacementCards != null;
    final catalogue =
        choosing ? AsyncData(replacementCards) : ref.watch(allCardsProvider);
    return catalogue.when(
      loading: () => const AppLoadingStrip(label: 'Loading card catalogue…'),
      error: (_, __) => AppStateCard(
        icon: Icons.error_outline_rounded,
        title: 'Card catalogue unavailable',
        message: 'Could not load the card catalogue.',
        action: TextButton(
          onPressed: () {
            ref.read(cardDataServiceProvider).invalidate();
            ref.invalidate(allCardsProvider);
          },
          child: const Text('Retry'),
        ),
      ),
      data: (cards) {
        final piles = <String, List<KingdomCard>>{};
        for (final card in cards) {
          (piles[card.pileId] ??= []).add(card);
        }
        bool isBanned(KingdomCard card) => piles[card.pileId]!
            .any((member) => config.isCardDisabled(member.id));
        final results = cards.where((card) {
          if (!choosing &&
              _ownedOnly &&
              !(config.ownsCard(card) &&
                  (config.collection != null ||
                      config.isExpansionOwned(card.expansion)))) {
            return false;
          }
          if (_bannedOnly && !isBanned(card)) return false;
          if (_expansion != null && card.expansion != _expansion) return false;
          if (_type != null && !card.types.contains(_type)) return false;
          if (_role != null && card.role != _role) return false;
          if (_cost != null && card.cost != _cost) return false;
          final translation = pack?.lookup(card.id);
          return [
            card.name,
            ...card.alternateNames,
            card.text,
            card.typeString,
            translation?.name ?? '',
            translation?.text ?? '',
          ].any((text) => text.toLowerCase().contains(_query));
        }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        if (choosing) {
          final seen = <String>{};
          results.removeWhere((card) => !seen.add(card.pileId));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  labelText: 'Search names, types, or rules',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!choosing)
                  FilterChip(
                    label: const Text('Owned only'),
                    selected: _ownedOnly,
                    onSelected: (value) => setState(() => _ownedOnly = value),
                  ),
                if (!choosing)
                  FilterChip(
                    label: const Text('Banned only'),
                    selected: _bannedOnly,
                    onSelected: (value) => setState(() => _bannedOnly = value),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.filter_list_rounded),
                  label: Text(_expansion == null &&
                          _type == null &&
                          _cost == null &&
                          _role == null
                      ? 'Filters'
                      : 'Filters active'),
                  onPressed: () => _showFilters(cards),
                ),
                if (!choosing && config.disabledCardIds.isNotEmpty)
                  TextButton(
                    onPressed: ref.read(configProvider.notifier).enableAllCards,
                    child: const Text('Unban all'),
                  ),
              ],
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No cards match these filters.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final card = results[index];
                        final slotId = card.pileId;
                        final members = piles[slotId]!;
                        final banned = isBanned(card);
                        String localName(KingdomCard member) {
                          final alias = pack?.lookup(member.id)?.name.trim();
                          return alias == null || alias.isEmpty
                              ? member.name
                              : alias;
                        }

                        final name = choosing
                            ? members.map(localName).join(' / ')
                            : localName(card);
                        final detail = [
                          if (!choosing && name != card.name) card.name,
                          if (!choosing)
                            ...card.alternateNames
                                .where((alias) => alias != name),
                          card.printedExpansionName,
                          card.typeString,
                          if (card.isAuxiliary) 'Auxiliary',
                          if (banned)
                            members.length > 1 ? 'Pile banned' : 'Banned',
                          if (widget.replacementNotes[slotId] case final note?)
                            note,
                        ].join(' · ');
                        return ListTile(
                          key: ValueKey(card.id),
                          leading: Text(card.costString),
                          title: Text(name),
                          subtitle: Text(detail),
                          onTap: () => KingdomCardWidget.showDetails(
                              context, card,
                              splitPileCards: members
                                  .where((member) => member.id != card.id)
                                  .toList()),
                          trailing: choosing
                              ? TextButton(
                                  onPressed: () => widget.onSelectPile!(slotId),
                                  child: Text('Choose',
                                      semanticsLabel: 'Choose $name'),
                                )
                              : card.isAuxiliary
                                  ? null
                                  : IconButton(
                                      tooltip:
                                          '${banned ? 'Unban' : 'Ban'} ${members.length > 1 ? 'whole pile' : name}',
                                      icon: Icon(banned
                                          ? Icons.undo_rounded
                                          : Icons.block_rounded),
                                      onPressed: () => ref
                                          .read(configProvider.notifier)
                                          .togglePileBan(members
                                              .map((member) => member.id)),
                                    ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showFilters(List<KingdomCard> cards) {
    final expansions = cards.map((card) => card.expansion).toSet().toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final types = cards.expand((card) => card.types).toSet().toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final costs = cards.map((card) => card.cost).toSet().toList()..sort();
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) {
          Widget filter<T>(String label, T? value, List<T> options,
              String Function(T) display, ValueChanged<T?> onChanged) {
            return DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text('Any $label'),
              items: [
                DropdownMenuItem<T>(child: Text('Any $label')),
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(display(option))),
              ],
              onChanged: (value) {
                setState(() => onChanged(value));
                refresh(() {});
              },
            );
          }

          return AlertDialog(
            title: const Text('Catalogue filters'),
            scrollable: true,
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  filter('expansion', _expansion, expansions,
                      (e) => e.displayName, (e) => _expansion = e),
                  filter('type', _type, types, (t) => t.displayName,
                      (t) => _type = t),
                  filter('coin cost', _cost, costs, (c) => '$c coins',
                      (c) => _cost = c),
                  filter('role', _role, CardRole.values, (r) => r.label,
                      (r) => _role = r),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _expansion = null;
                    _type = null;
                    _cost = null;
                    _role = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear filters'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }
}
